c------------------------------------------------------------------
c     recompute partitions
       subroutine recompute_partitions_cpu
          include 'SIZE'
          include 'INPUT'
          include 'PARALLEL'
          include 'TSTEP'

          parameter (lr=16*ldim,li=5+6)
          common /nekmpi/ nid_,np_,nekcomm,nekgroup,nekreal
          common /elementload/ gfirst, inoassignd,
     >                resetFindpts, pload(lelg)
          integer gfirst, inoassignd, resetFindpts, pload

          integer nw
          common /particlenumber/ nw

          real   xerange(2,3,lelt)
          common /elementrange/ xerange

          integer newgllnid(lelg), trans(3, lelg), trans_n, psum(lelg)
c          integer total
          integer e,eg,eg0,eg1,mdw,ndw
          real ratio
          integer ntuple, i, el, delta, nxyz
c         common /ptpointers/ jrc,jpt,je0,jps,jai,nai,jr,jd,jx,jy,jz,jx1
c    $            ,jx2,jx3,jv0,jv1,jv2,jv3,ju0,ju1,ju2,ju3,jf0,jar,i
c    $             jaa,jab,jac,jad,nar
          common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >                 ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >                 ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid
          common  /cparti/ ipart(li,lpart)
          common  /iparti/ n,nr,ni
          integer particleMap(3, lelt)

!         if(nid .eq. 0) then
!             print *, 'old pload:'
!             call printi(pload, nelgt)
!         endif
c         Step 1: Send number of particles in each element to Processor 0.
          nxyz = nx1*ny1*nz1   !total # of grid point per element
          delta = ceiling(nw*1.0/nelgt)
          ratio = 2.0
          ntuple = nelt
          do i=1,ntuple
             eg = lglel(i)
             particleMap(1,i) = eg
             particleMap(2,i) = 0        ! processor id to send for element eg
             particleMap(3, i) = 0      !  #of particles in each element, reinitialize to 0, otherwise it keeps the previous value
          enddo

          !print *, 'nid: ', nid, 'ipart: ', ipart(1,1), ipart(2,1),
          !>      ipart(3,1), lglel(ipart(3,1)+1)
          do ip=1,n
             el = ipart(je0, ip) + 1      ! element id in ipart is start from 0, so add 1
             particleMap(3, el) = particleMap(3, el) + 1
          enddo

c         gas_right_boundary = exp(TIME/2.0)

          do i=1,ntuple
c            x_left_boundary = xerange(1,1,i)
c            if (x_left_boundary .lt. gas_right_boundary) then
c            !if (vx(1,1,1,i) .ne. 0) then
                particleMap(3, i) = particleMap(3, i) + delta*ratio
c            else
c               particleMap(3, i) = 0
c               !print *, 'element: ', particleMap(1,i), 'gas 0'
c            endif
          enddo

          mdw=3
          ndw=nelgt
          key = 2  ! processor id is in wk(2,:)
          call crystal_ituple_transfer(cr_h,particleMap,
     $                                 mdw,ntuple,ndw,key)

c         Step 2: Processor 0 sorts the elements according to global element id
c                 Processor 0 also assigns new gllnid
          if (nid .eq. 0) then
c         print *, 'time: ', TIME, 'gas_right_boundary:', 
c    $      gas_right_boundary, 'delta: ', delta
             key=1
             nkey = 1
             call crystal_ituple_sort(cr_h,particleMap,mdw,
     $                                ntuple,key,nkey)
             do i=1,ntuple ! ntuple changed to toal number of elements after tuple transfer
                pload(i) = particleMap(3, i)
             enddo

!           print *, 'nelgt:', nelgt, 'new pload:'
!           call printi(pload, nelgt)
             !print *, 'new pload/n'
             !call printr(newPload, lelt)
             call izero(psum, lelg)
             call preSum(pload, psum, nelgt)
             print *, 'recompute_partitions: psum(nelgt): ', psum(nelgt)
             !call printr(newPload, lelt)

             call izero(newgllnid, lelg)
!            print *, nid, 'print new gllnid'
             call ldblce(psum, nelgt, newgllnid, np_)
!            call printi(newgllnid, nelgt)
          endif
          call bcast(newgllnid,4*lelg)
          print *, "finished broadcast newgllnid in processor", nid

          call izero(trans, 3*lelg)
          call track_elements(gllnid, newgllnid, nelgt, trans,
     $                               trans_n, lglel, lelt)
c         print *, 'print trans'
c         do 110 i=1, trans_n
c           print *, trans(1, i), trans(2, i), trans(3, i)
c 110  continue

          print *, "finished track elements in processor", nid
          call track_particles(trans, trans_n)
          call mergePhigArray_cpu(newgllnid, trans, trans_n)
          call mergeUArray_cpu(newgllnid)

          call icopy(gllnid, newgllnid, lelg)

          return
          end

c------------------------------------------------------------------
      subroutine preSum(pload, psum, len)
      integer pload(len)
      integer psum(len)
      integer i
      psum(1)=pload(1)
      do 30 i=2, len
          psum(i)=psum(i-1)+pload(i)
  30  continue

c      do 50 i=1, len
c         pload(i)=psum(i)
c  50  continue

      return
      end

c--------------------------------------------------------
      subroutine ldblce(psum, nelgt, gllnid, np)
c         parameter (nelgt = 12, np=6, cpu2gpu=3, gpuload= 0.9, lelg=64)
         include 'SIZE'
         include 'INPUT'
         !common /nekmpi/ nid,np,nekcomm,nekgroup,nekreal
         integer psum(nelgt)
         integer nelgt, np
         integer gllnid(nelgt)

         real thresh(np) !hold thresh for each proc
         integer num_cores, numgpu, pos(np+1)
         integer i, j, k
         real percentCPULoad, threshNode, threshProc, threshi
         !data thresh/np*0.0/   !intialize thresh to 0
         !data pos /np*0, 0/

         call rzero(thresh, np)
         call izero(pos, np+1)
         num_cores = param(70) ! #of cores in each node
         percentCPULoad = 1-param(71)
         numgpu = np /num_cores   ! #of nodes
         threshNode = psum(nelgt)*1.0/numgpu  ! the load for each node
         threshProc = threshNode * percentCPULoad/ (num_cores - 1) ! the load for cpu
         print *, num_cores, numgpu, threshNode, threshProc
c        compute thresh array
         if(num_cores>1) then !hybrid of cpu and gpu
             thresh(1)=threshProc
         else
             thresh(1) = threshNode
         endif
         do i = 2, np
             if(mod(i,num_cores) .eq. 0) then !GPU
                thresh(i) = threshNode * (i/num_cores);
             else
                thresh(i) = thresh(i-1)+threshProc
             endif
         enddo
        print *, 'thresh: '
        call printr(thresh, np)

c      assign gllnid
c      Step 1: divide psum into numgpu parts, assign pos(i*num_cores)
       k = 1
       pos(1) = 0
       do i = 1, numgpu
          threshi = thresh(i*num_cores)
          do j = k, nelgt-1
             if(abs(psum(j)-threshi) .lt. abs(psum(j+1)-threshi)) then
                pos(i*num_cores+1) = j
                k = j
                exit
             else
                pos(i*num_cores+1) = j+1
                k = j+1
             endif
          enddo
       enddo
       print *, 'pos: ', pos

c     Step 2: assign the rest of pos
      do i = 1, numgpu
         k = i*num_cores - 1
         threshi = thresh(k)
         do j = pos(i*num_cores+1)-1, pos((i-1)*num_cores+1)+1, -1
            if(abs(psum(j+1)-threshi) .lt. abs(psum(j)-threshi)) then
                pos(k+1) = j+1
                if((k .gt. (i-1)*num_cores+1)) then
                   k = k - 1
                   threshi = thresh(k)
                   if(j .eq. pos((i-1)*num_cores+1)+1) then ! this part is the same as the next else part, since i lost j .eq. pos((i-1)*num_cores+1)+1 situation
                      if(abs(psum(j) - threshi) <threshProc) then
                          pos(k+1) = j
                      else
                          pos(k+1) = j+1
                      endif
                   endif
                else
                   exit
                endif
            else
                if(j .eq. pos((i-1)*num_cores+1)+1) then
                   if(abs(psum(j) - threshi) <threshProc) then
                       pos(k+1) = j
c                  else
c                      pos(k+1) = j+1
                   endif
                endif
            endif
         enddo
      enddo
      print *, 'pos: ', pos
c     Step 3: eleminate 0 in pos(2:np+1)
      do i=2, np+1
         if (pos(i) .eq. 0)  pos(i) = pos(i-1)
      enddo
      print *, 'pos: ', pos

c     Step 4: assign gllnid 
      do i=1, np
          do j=pos(i)+1, pos(i+1)
             gllnid(j)=i-1
          enddo
      enddo
c     print *, 'gllnid ', gllnid
      return
      end

!----------------------------------------------------------------------------------
c subroutine of track elements to be send and received
      subroutine track_elements(gllnid, newgllnid, len, trans,
     $                     trans_n, lglel, lelt)
       include 'SIZE'
       integer gllnid(len), newgllnid(len), trans(3, len), trans_n
       integer lglel(lelt)
       !trans: first column stores the source pid, second column stores the target pid, the third column stores the element id
       integer i, j; !local variable

       trans_n=1;
       j=0;
       do i=1, len
          if ((gllnid(i) .eq. nid)) then
             j = j+1;
             if(gllnid(i) .ne. newgllnid(i)) then
c since added gllnid(i) .eq. nid, right now, the trans in processor i only store the elements that he shold send. Not all the processors.            
             trans(1, trans_n) = gllnid(i);
             trans(2, trans_n) = newgllnid(i);
             trans(3, trans_n) = lglel(j)
             trans_n=trans_n+1;
           endif
         endif
       enddo
       trans_n=trans_n-1;  !the length of trans
c      print *, trans_n, 'print again in track elements'
c       do 110 i=1, trans_n
          !do 120 j=1, width
c           print *, i, trans(i,1), trans(i,2), trans(i,3)
c  120     continue
c  110  continue

       return

      end

!--------------------------------------------------------------------------------
c update the particles that are in the elements to be
c transferred, and set jpt to the destination processor
       subroutine track_particles(trans, trans_n)
       include 'SIZE'
       include 'PARALLEL'

       integer trans(3, lelg), trans_n
       parameter (lr=16*ldim,li=5+6)
       common  /iparti/ n,nr,ni
       common  /cpartr/ rpart(lr,lpart) ! Minimal value of lr = 16*ndim
       common  /cparti/ ipart(li,lpart) ! Minimal value of li = 5
       common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >                ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >                ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid
       common /myparth/ i_fp_hndl, i_cr_hndl


       integer ip, it, e
       logical partl         ! This is a dummy placeholder, used in cr()
       nl = 0                ! No logicals exchanged


c     change ipart(je0,i) to global element id
       ip=0
       do ip = 1, n
           e = ipart(je0, ip) + 1 ! je0 start from 0
           ipart(je0, ip) = lglel(e)
       enddo

       do ip = 1, n
          !e = ipart(je0,ip)
          do it = 1, trans_n
             if(ipart(je0, ip) .eq. trans(3, it)) then
                ipart(jpt, ip) = trans(2, it) !new processor
                exit
             endif
          enddo
          ipart(jps, ip) = ipart(jpt, ip)
       enddo

       call crystal_tuple_transfer(i_cr_hndl,n,lpart
     $              , ipart,ni,partl,nl,rpart,nr,jps)


       print *, 'compeleted track particles'
       return
      end

!-----------------------------------------------------------------------------
       subroutine printr(pload, len)
          real pload(len)
          integer i
          do 40 i=1, len
             print *, pload(i)
   40     continue
       return
       end

!-----------------------------------------------------------------------------

c subroutine to merge phig array
          subroutine mergePhigArray_cpu(newgllnid, trans, trans_n)
          include 'SIZE'
          include 'INPUT'
          include 'PARALLEL'
          include 'TSTEP'
          include 'CMTDATA'

          integer newgllnid(lelg), trans(3, lelg), trans_n
          real phigarray(lx1*ly1*lz1, lelt) !keke changed real to integer to use crystal_ituple_transfer
          integer procarray(3, lelg) !keke changed real to integer to use crystal_ituple_transfer
          real tempphig(lx1*ly1*lz1, lelt)
          logical partl
          integer nl, sid, eid
          integer key, nkey, ifirstelement, ilastelement, phig_n

c         Step 1: Build phigarray for the elements to be transferred to neighboring processes.
          index_n=1;
          nl=0
          nxyz = lx1*ly1*lz1
          do i=1, nelt
              ieg = lglel(i)
              if ((gllnid(ieg) .eq. nid) .and.
     $                     (gllnid(ieg) .ne. newgllnid(ieg))) then
                  procarray(1, index_n) = gllnid(ieg)
                  procarray(2, index_n) = newgllnid(ieg)
                  procarray(3, index_n) = ieg
                  do k=1, lz1
                      do n=1, ly1
                         do m=1, lx1
                            ind=m+(n-1)*ly1+(k-1)*lz1*ly1
                            phigarray(ind, index_n) = phig(m,n,k,i)
                         enddo
                      enddo
                  enddo
              index_n=index_n+1
              endif
          enddo
          index_n=index_n-1

c          print *, index_n, lelg, nid

c         Step 2: Send/receive phigarray to/from neighbors
          key=2
          call crystal_tuple_transfer(cr_h, trans_n, nelgt, trans,
     $                    3, partl, nl, phigarray,nxyz,key)
c         print *, 'nid: ', nid, 'received trans_n', trans_n      
c         Step 2: Sort the received phigarray based on global element number
          key=3
          nkey=1
          call crystal_tuple_sort(cr_h, trans_n, trans, 3,
     $               partl, nl, phigarray, nxyz, key,nkey)

c         Step 4: set start id and end id of phig of existing (not transferred) elements
          !start id is the index of the first element that has not been sent to the left neighbor
          !end id is the index of the last element that has not been sent to the right neighbor
          sid=1
          ifirstelement = lglel(sid)
          phig_n=0
          do i=1, index_n
              !if (procarray(3,i) .lt. ifirstelement) then
      !            set tempphig from phigarray
                   !phig_n=phig_n+1
                   !do j=1, nxyz
              if (procarray(3,i) .eq. ifirstelement) then
                       sid=sid+ 1
                       ifirstelement=lglel(sid)
              endif
          enddo
          eid = nelt
          ilastelement = lglel(eid)
          do i=index_n, 1, -1
               if (procarray(3,i) .eq. ilastelement) then
                   eid = eid -1
                   ilastelement = lglel(eid)
               endif
          enddo

c         Step 5: Update local phig based on elements 
c                 a) received from left neighbor
c                 b) existing elements
c                 c) received from right neighbor
          ifirstelement = lglel(sid)
          do i=1, trans_n
              if (trans(3, i) .lt. ifirstelement) then
                  ! set tempphig from phigarray
                   phig_n=phig_n+1
                   do j=1, nxyz
                      tempphig(j,phig_n)=phigarray(j,i)
                   enddo
              endif
          enddo

          if (sid .le. eid) then  !set tempphig from original phig
              do i=sid, eid
                  phig_n=phig_n+1
                  do k=1, lz1
                      do n=1, ly1
                         do m=1, lx1
                            ind=m+(n-1)*ly1+(k-1)*lz1*ly1
                            tempphig(ind, phig_n) = phig(m,n,k,i)
                         enddo
                      enddo
                  enddo
              enddo
          endif
          ilastelement = lglel(eid)
          do i=1, trans_n
              if (trans(3, i) .gt. ilastelement) then
                  ! set tempphig from phigarray
                   phig_n=phig_n+1
                   do j=1, nxyz
                      tempphig(j,phig_n)=phigarray(j,i)
                   enddo
              endif
          enddo
          !copy tempphig to phig
          do i=1, phig_n
             do k=1, lz1
                do n=1, ly1
                    do m=1, lx1
                        ind=m+(n-1)*ly1+(k-1)*lz1*ly1
                        phig(m,n,k,i) = tempphig(ind, i)
                    enddo
                enddo
             enddo
          enddo
       end
!-----------------------------------------------------------------------------
          subroutine mergeUArray_cpu(newgllnid)
          include 'SIZE'
          include 'INPUT'
          include 'PARALLEL'
          include 'CMTDATA'

          integer newgllnid(lelg), trans(3, lelg)
          real uarray(lx1*ly1*lz1, lelt)
          integer procarray(3, lelg) !keke changed real to integer to use crystal_ituple_transfer
          real tempu(lx1*ly1*lz1, lelt)
          logical partl
          integer nl, sid, eid
          integer key, nkey, ifirstelement, ilastelement, u_n, trans_n

          index_n=1
          trans_n=0
          nxyz = lx1*ly1*lz1*toteq
          nl=0
          do i=1, nelt
              ieg = lglel(i)
              if ((gllnid(ieg) .eq. nid) .and.
     $                     (gllnid(ieg) .ne. newgllnid(ieg))) then
                  procarray(1, index_n) = gllnid(ieg)
                  procarray(2, index_n) = newgllnid(ieg)
                  procarray(3, index_n) = ieg
                  trans(1, index_n) = gllnid(ieg)
                  trans(2, index_n) = newgllnid(ieg)
                  trans(3, index_n) = ieg
                  do l=1, toteq
                      do k=1, lz1
                          do n=1, ly1
                             do m=1, lx1
                                ind=m+(n-1)*ly1+(k-1)*lz1*ly1+
     $                                           (l-1)*toteq*lz1*ly1
                                uarray(ind, index_n) = u(m,n,k,l,i)
                             enddo
                          enddo
                      enddo
                  enddo
              index_n=index_n+1
              endif
          enddo
          index_n=index_n-1
          trans_n=index_n
c          print *, index_n, trans_n, lelt, nid

          key=2
          call crystal_tuple_transfer(cr_h, trans_n, nelgt, trans,
     $                    3, partl, nl, uarray,nxyz,key)
c         print *, 'nid: ', nid, 'trans_n', trans_n      
          key=3
          nkey=1
          call crystal_tuple_sort(cr_h, trans_n, trans, 3,
     $               partl, nl, uarray, nxyz, key,nkey)

          !Update u
          ! set sid and eid
          sid=1
          ifirstelement = lglel(sid)
          u_n=0
          do i=1, index_n
              if (procarray(3,i) .eq. ifirstelement) then
                       sid=sid+ 1
                       ifirstelement=lglel(sid)
              endif
          enddo
          eid = nelt
          ilastelement = lglel(eid)
          do i=index_n, 1, -1
               if (procarray(3,i) .eq. ilastelement) then
                   eid = eid -1
                   ilastelement = lglel(eid)
               endif
          enddo

          ifirstelement = lglel(sid)
          do i=1, trans_n
              if (trans(3, i) .lt. ifirstelement) then
                  ! set tempu from uarray
                   u_n=u_n+1
                   do j=1, nxyz
                      tempu(j,u_n)=uarray(j,i)
                   enddo
              endif
          enddo


          if (sid .le. eid) then
              do i=sid, eid      !set tempu from original u
                  u_n=u_n+1
                  do l=1, toteq
                      do k=1, lz1
                          do n=1, ly1
                             do m=1, lx1
                                ind=m+(n-1)*ly1+(k-1)*lz1*ly1+
     $                                           (l-1)*toteq*lz1*ly1
                                tempu(ind, u_n) = u(m,n,k,l,i)
                             enddo
                          enddo
                      enddo
                  enddo
              enddo
          endif
          ilastelement = lglel(eid)
          do i=1, trans_n
              if (trans(3, i) .gt. ilastelement) then
                  ! set tempu from uarray
                   u_n=u_n+1
                   do j=1, nxyz
                      tempu(j,u_n)=uarray(j,i)
                   enddo
              endif
          enddo
          !copy tempu to u
              do i=1, u_n
                  do l=1, toteq
                      do k=1, lz1
                          do n=1, ly1
                             do m=1, lx1
                                ind=m+(n-1)*ly1+(k-1)*lz1*ly1+
     $                                           (l-1)*toteq*lz1*ly1
                                uarray(ind, index_n) = u(m,n,k,l,i)
                                u(m,n,k,l,i) = tempu(ind, i)
                             enddo
                          enddo
                      enddo
                  enddo
              enddo
c      print *, "Update u array: u_n", u_n
       end

c-------------------------------------------------------------------------
      subroutine update_ipartje0_to_local_cpu
      include 'SIZE'
      include 'PARALLEL'
      parameter (lr=16*ldim,li=5+6)
      common  /iparti/ n,nr,ni
      common  /cpartr/ rpart(lr,lpart) ! Minimal value of lr = 14*ndim+1
      common  /cparti/ ipart(li,lpart) ! Minimal value of lr = 14*ndim+1
      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >                ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >                ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid
      common /myparth/ i_fp_hndl, i_cr_hndl
      integer ip, e
      logical partl         ! This is a dummy placeholder, used in cr()
      nl = 0 
    
      ip=0
      do ip = 1, n
         e = ipart(je0, ip)
         ipart(je0, ip) = gllel(e) - 1  ! je0 start from 0
      enddo
c     Sort by element number 
      call crystal_tuple_sort(i_cr_hndl,n
     $          , ipart,ni,partl,nl,rpart,nr,je0,1)

      end

c------------------------------------------------------------------------------
      subroutine reinitialize
      include 'SIZE'
      include 'TOTAL'
      include 'DOMAIN'
      include 'ZPER'
c
      include 'OPCTR'
      include 'CTIMER'

      common /elementload/ gfirst, inoassignd, resetFindpts, pload(lelg)
      integer gfirst, inoassignd, resetFindpts, pload

      inoassignd = 0
      call readat

      ifsync_ = ifsync
      ifsync = .true.

      call setvar          ! Initialize most variables !skip 

#ifdef MOAB
      if (ifmoab) call nekMOAB_bcs  !   Map BCs
#endif

      instep=1             ! Check for zero steps
      if (nsteps.eq.0 .and. fintim.eq.0.) instep=0

      igeom = 2
      call setup_topo      ! Setup domain topology  

      call genwz           ! Compute GLL points, weights, etc.

      call io_init         ! Initalize io unit

      if (ifcvode.and.nsteps.gt.0)
     $   call cv_setsize(0,nfield) !Set size for CVODE solver

      if(nio.eq.0) write(6,*) 'call usrdat'
      call usrdat
      if(nio.eq.0) write(6,'(A,/)') ' done :: usrdat'
      call gengeom(igeom)  ! Generate geometry, after usrdat 

      if (ifmvbd) call setup_mesh_dssum ! Set mesh dssum (needs geom)

      if(nio.eq.0) write(6,*) 'call usrdat2'
      call usrdat2
      if(nio.eq.0) write(6,'(A,/)') ' done :: usrdat2'

      call geom_reset(1)    ! recompute Jacobians, etc.
      call vrdsmsh          ! verify mesh topology

      call echopar ! echo back the parameter stack
      call setlog  ! Initalize logical flags

      call bcmask  ! Set BC masks for Dirichlet boundaries.

      if (fintim.ne.0.0.or.nsteps.ne.0)
     $   call geneig(igeom) ! eigvals for tolerances

      call vrdsmsh     !     Verify mesh topology

      call dg_setup    !     Setup DG, if dg flag is set.

      if (ifflow.and.(fintim.ne.0.or.nsteps.ne.0)) then    ! Pressure solver 
         call estrat                                       ! initialization.
         if (iftran.and.solver_type.eq.'itr') then         ! Uses SOLN space 
            call set_overlap                               ! as scratch!
         elseif (solver_type.eq.'fdm'.or.solver_type.eq.'pdm')then
            ifemati = .true.
            kwave2  = 0.0
            if (ifsplit) ifemati = .false.
            call gfdm_init(nx2,ny2,nz2,ifemati,kwave2)
         elseif (solver_type.eq.'25D') then
            call g25d_init
         endif
      endif

      call init_plugin !     Initialize optional plugin

      if(nio.eq.0) write(6,*) 'call usrdat3'
      call usrdat3
      if(nio.eq.0) write(6,'(A,/)') ' done :: usrdat3'

      call cmt_switch          ! Check if compiled with cmt
      if (ifcmt) then          ! Initialize CMT branch
        call nek_cmt_init
        if (nio.eq.0) write(6,*)'Initialized DG machinery'
      endif
      end
c-----------------------------------------------------------------------
      subroutine printVerify
      include 'SIZE'
      common /nekmpi/ nid_,np_,nekcomm,nekgroup,nekreal

      print *, 'nid: ', nid_, 'nelt: ', nelt
      end

c------------------------------------------------------------------------
c      print array integer
       subroutine printi(pos, len)
          integer pos(len)
          integer i
          do 40 i=1, len
             print *, pos(i)
   40     continue
       return
       end

