c-----------------------------------------------------------------------
      subroutine userflux  (fluxout)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE' ! probably want to start following nek convention
                       ! and use this routine pointwise
      real fluxout(lx1*lz1)
      integer e,f,eg

      do i=1,nx1*nz1
         fluxout(i)=0.0 ! adiabatic
      enddo
      return
      end
c-----------------------------------------------------------------------
      subroutine userEOS(ix,iy,iz,eg)
      include 'SIZE'
      include 'NEKUSE'
      include 'PARALLEL'
      include 'CMTDATA'
      include 'PERFECTGAS'
      integer e,eg

      cp=cpgref
      cv=cvgref
      temp=e_internal/cv
      asnd=MixtPerf_C_GRT(gmaref,rgasref,temp)
      pres=MixtPerf_P_DRT(rho,rgasref,temp)
      return
      end subroutine userEOS
!-----------------------------------------------------------------------
      subroutine uservp (ix,iy,iz,eg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      integer e,eg

      udiff =0.
      utrans=0.
      return
      end
c-----------------------------------------------------------------------
      subroutine userf  (ix,iy,iz,eg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      integer e,eg

      ffx = 0.0
      ffy = 0.0
      ffz = 0.0
      return
      end
c-----------------------------------------------------------------------
      subroutine userq  (ix,iy,iz,eg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      integer e,eg

      qvol   = 0.0
      return
      end
c-----------------------------------------------------------------------
c       userchk
c         Called after every time step and just before the first time
c         step.
c
c         istep: the time step counter
c
      subroutine process_cpu_particles
      include 'SIZE'  
      include 'TOTAL' 
      include 'CTIMER'
      include 'CMTTIMERS'

c     pt_timers - particle timer
c     scrt_timers - scratch timer (IO)
      real    pt_timers(10), scrt_timers(10)
      common /trackingtime/ pt_timers, scrt_timers

c     xdrange - global domain boundary [min,max][x,y,z]
      real   xdrange(2,3)
      common /domainrange/ xdrange

c     xerange - local domain (element) [min,max][x,y,z][element index]
      real   xerange(2,3,lelt)
      common /elementrange/ xerange

c     initialization on first step for domain sizes
      scrt_timers(1) = dnekclock()
      call stokes_particles
      pt_timers(1) = pt_timers(1) + dnekclock() - scrt_timers(1)
      ipttime = 10
      if(istep.eq.nsteps.or.
     &      (istep.gt.1.and.mod(istep,ipttime).eq.0))then
         ptdum = glsum(ftime,1)
         if(nid.eq.0) write(6,10)'flow solver time     ', ptdum
     &                        , ptdum/istep      
         ptdum = glsum(pt_timers(1),1)
         if(nid.eq.0) write(6,10)'stokes_particles time', ptdum
     &                        , ptdum/istep      
         ptdum = glsum(pt_timers(2),1)
         if(nid.eq.0) write(6,10)'init_stokes_ptls time', ptdum
     &                        , ptdum/istep      
         ptdum = glsum(pt_timers(3),1)
         if(nid.eq.0) write(6,10)'updt_stokes_ptls time', ptdum
     &                        , ptdum/istep      
         ptdum = glsum(pt_timers(4),1)
         if(nid.eq.0) write(6,10)'interp_u_for_adv time', ptdum
     &                        , ptdum/istep      
         ptdum = glsum(pt_timers(5),1)
         if(nid.eq.0) write(6,10)'find_pts   time      ', ptdum
     &                        , ptdum/istep
         ptdum = glsum(pt_timers(6),1)
         if(nid.eq.0) write(6,10)'crystal router time  ', ptdum
     &                        , ptdum/istep
         ptdum = glsum(pt_timers(7),1)
         if(nid.eq.0) write(6,10)'findpts_eval 3 time  ', ptdum
     &                        , ptdum/istep
         ptdum = glsum(pt_timers(8),1)
         if(nid.eq.0) write(6,10)'BDF3/EX2             ', ptdum
     &                        , ptdum/istep
         ptdum = glsum(pt_timers(9),1)
         if(nid.eq.0) write(6,10)'locate remote part   ', ptdum
     &                        , ptdum/istep
      endif
      ifxyo=.true.
      if(istep.gt.1)ifxyo=.false.
10    format(A21,1x,2(f14.7,1x))
      return
      end
c-----------------------------------------------------------------------
      subroutine userbc (ix,iy,iz,iside,eg)
c     NOTE ::: This subroutine MAY NOT be called by every process
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      integer e,eg

      ux   = 0.0  !-y
      uy   =  0.0 !x
      uz   =  0.0
      temp =  293  !0.0
      return
      end
c-----------------------------------------------------------------------
      subroutine useric (ix,iy,iz,eg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      include 'CMTDATA'
      include 'PERFECTGAS'
      integer e,eg

      temp = 293   !1.0!sin(pi*x)
      ux   = 0.0 !0.15
      uy   = 0.0
      uz   = 0.0
      phi  = 1.0
      varsic(1) = MixtPerf_D_PRT(1.0,rgasref,temp)*phi
      varsic(2) = varsic(1)*ux
      varsic(3) = varsic(1)*uy
      varsic(4) = varsic(1)*uz
      varsic(5) = cvgref*temp*varsic(1)+
     >            0.5*(varsic(2)**2+varsic(3)**2+varsic(4)**2)/varsic(1)
      rho  = varsic(1)/phi
      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat
      include 'SIZE'
      include 'TOTAL'
      include 'CMTDATA'
      include 'CMTTIMERS'
      include 'PERFECTGAS'
      integer e

      molmass    = 8314.3
      muref      = 0.0
      coeflambda = -2.0/3.0
      suthcoef   = 1.0
      reftemp    = 1.0
      prlam      = 0.72
      pinfty     = 1.0
      gmaref     = 1.4
      rgasref    = MixtPerf_R_M(molmass,dum)
      cvgref     = rgasref/(gmaref-1.0)
      cpgref     = MixtPerf_Cp_CvR(cvgref,rgasref)
      gmaref     = MixtPerf_G_CpR(cpgref,rgasref) 

      res_freq = 10000000
      flio_freq = 200

      NCUT =  int(lx1/2)
      NCUTD = lxd
      wght  = 0.2
      wghtd = 0.2
      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat2
      include 'SIZE'
      include 'TOTAL'
      include 'CMTDATA'
      include 'CMTBCDATA'

      real   xdrange(2,3)
      common /domainrange/ xdrange
      real   xerange(2,3,lelt)
      common /elementrange/ xerange
c     added by keke
      common /elementload/ gfirst, inoassignd, resetFindpts, pload(lelg)
      integer gfirst, inoassignd, resetFindpts, pload
c     end added by keke

      outflsub=.false.
      IFCNTFILT=.false.
      ifrestart=.false.
      ifbr1=.false.
      ifvisc=.false.
      gasmodel = 1

c     x0 = -1.
c     x1 =  1.

      x0 = 0.
      x1 = 2*pi
      call rescale_x(xm1,x0,10.0)   !x1)
      call rescale_x(ym1,x0,1.0)    !x1)
      call rescale_x(zm1,x0,1.0)    !x1)

      if((istep.eq.0) .or. (gfirst .eq. 0)) then !gfirst .eq. 0 added by keke
        call domain_size(xdrange(1,1),xdrange(2,1),xdrange(1,2)
     $                  ,xdrange(2,2),xdrange(1,3),xdrange(2,3))
        ntot = lx1*ly1*lz1*nelt
        nxyz = lx1*ly1*lz1
        do ie = 1,nelt
           xerange(1,1,ie) = vlmin(xm1(1,1,1,ie),nxyz)
           xerange(2,1,ie) = vlmax(xm1(1,1,1,ie),nxyz)
           xerange(1,2,ie) = vlmin(ym1(1,1,1,ie),nxyz)
           xerange(2,2,ie) = vlmax(ym1(1,1,1,ie),nxyz)
           xerange(1,3,ie) = vlmin(zm1(1,1,1,ie),nxyz)
           xerange(2,3,ie) = vlmax(zm1(1,1,1,ie),nxyz)
        enddo
      endif

      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat3
      return
      end
c-----------------------------------------------------------------------
      subroutine set_part_pointers
      include 'SIZE'
c     Minimal value of ni = 5
c     Minimal value of nr = 16*ndim 
      common  /iparti/ n,nr,ni
c     common /ptpointers/ jrc,jpt,je0,jps,jai,nai,jr,jd,jx,jy,jz,jx1
c    $            ,jx2,jx3,jv0,jv1,jv2,jv3,ju0,ju1,ju2,ju3,jf0,jar,
c    $            jaa,jab,jac,jad,nar
      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid

      jrc = 1 ! Pointer to findpts return code
      jpt = 2 ! Pointer to findpts return processor id
      je0 = 3 ! Pointer to findpts return element id
      jps = 4 ! Pointer to proc id for data swap
      jpid1 = 5 ! initial proc number
      jpid2 = 6 ! initial local particle id
      jpid3 = 7 ! initial time step introduced
      jpnn = 8 ! initial time step introduced
      jpid = 9 ! initial time step introduced
      jai = 10 ! Pointer to auxiliary integers
      nai = ni - (jai-1)  ! Number of auxiliary integers
      if (nai.le.0) call exitti('Error in nai:$',ni)

      jr  = 1         ! Pointer to findpts return rst variables
      jd  = jr + ndim ! Pointer to findpts return distance
      jx  = jd + 1    ! Pointer to findpts input x value
      jy  = jx + 1    ! Pointer to findpts input y value
      jz  = jy + 1    ! Pointer to findpts input z value

      jx1 = jx + ndim ! Pointer to xyz at t^{n-1}
      jx2 = jx1+ ndim ! Pointer to xyz at t^{n-1}
      jx3 = jx2+ ndim ! Pointer to xyz at t^{n-1}

      jv0 = jx3+ ndim ! Pointer to current particle velocity
      jv1 = jv0+ ndim ! Pointer to particle velocity at t^{n-1}
      jv2 = jv1+ ndim ! Pointer to particle velocity at t^{n-2}
      jv3 = jv2+ ndim ! Pointer to particle velocity at t^{n-3}

      ju0 = jv3+ ndim ! Pointer to current fluid velocity
      ju1 = ju0+ ndim ! Pointer to fluid velocity at t^{n-1}
      ju2 = ju1+ ndim ! Pointer to fluid velocity at t^{n-2}
      ju3 = ju2+ ndim ! Pointer to fluid velocity at t^{n-3}

      jf0 = ju3+ ndim ! Pointer to forcing at current timestep

      jar = jf0+1 ! Pointer to auxiliary reals
      jaa = jar + 1  ! for storing a as in x = x0 + at
      jab = jaa + 1  ! for storing b as in x = x0 + bt
      jac = jab + 1  ! for storing c as in x = x0 + ct
      jad = jac + 1  ! for storing distance d on line from (X0, y0, z0)

      nar = nr - (jar-1)  ! Number of auxiliary reals

      if (nar.le.0) call exitti('Error in nar:$',nr)
      return
      end
c----------------------------------------------------------------------
      subroutine interp_comm_part()

      include 'SIZE'
      include 'TOTAL'
      include 'CTIMER'

      common  /iparti/ n,nr,ni

      common /nekmpi/ mid,mp,nekcomm,nekgroup,nekreal
      common /myparth/ i_fp_hndl, i_cr_hndl

      common /elementload/ gfirst, inoassignd, resetFindpts, pload(lelg)
      integer gfirst, inoassignd, resetFindpts, pload

      integer icalld1
      save    icalld1
      data    icalld1 /0/

      logical partl         ! This is a dummy placeholder, used in cr()
      nl = 0                ! No logicals exchanged

      if ((icalld1.eq.0) .or. (resetFindpts .eq. 1))then
         tolin = 1.e-12
         if (wdsize.eq.4) tolin = 1.e-6
         call intpts_setup  (tolin,i_fp_hndl)
         call crystal_setup (i_cr_hndl,nekcomm,np)
         icalld1 = icalld1 + 1
         resetFindpts = 0
c        added by keke
         print *, 'before transfer nid: ', nid, '# particles: ', n
c        end added by keke
      endif

      end
c----------------------------------------------------------------------
      subroutine interp_u_for_adv_gpubased(rpart,nr,ipart,ni,n,ux,uy,uz)

c     Interpolate fluid velocity at current xyz points and move
c     data to the processor that owns the points.
c     Input:    n = number of points on this processor
c     Output:   n = number of points on this processor after the move
c     Code checks for n > lpart and will not move data if there
c     is insufficient room.
      include 'SIZE'
      include 'TOTAL'
      include 'CTIMER'

      common /nekmpi/ mid,mp,nekcomm,nekgroup,nekreal
      common /myparth/ i_fp_hndl, i_cr_hndl

      real    pt_timers(10), scrt_timers(10)
      common /trackingtime/ pt_timers, scrt_timers

      real    rpart(nr,n),ux(1),uy(1),uz(1)
      integer ipart(ni,n)

      parameter (lrf=4+ldim,lif=5+1)
      real               rfpts(lrf,lpart)
      common /fptspartr/ rfpts
      integer            ifpts(lif,lpart),fptsmap(lpart)
      common /fptsparti/ ifpts,fptsmap

      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid


c     common /elementload/ gfirst, inoassignd, resetFindpts, pload(lelg)
c     integer gfirst, inoassignd, resetFindpts, pload

      integer icalld1
      save    icalld1
      data    icalld1 /0/

      logical partl         ! This is a dummy placeholder, used in cr()
      nl = 0                ! No logicals exchanged

      scrt_timers(4) = dnekclock()
      if ((icalld1.eq.0)) then ! .or. (resetFindpts .eq. 1)) then
         tolin = 1.e-12
         if (wdsize.eq.4) tolin = 1.e-6
         call intpts_setup  (tolin,i_fp_hndl)
         call crystal_setup (i_cr_hndl,nekcomm,np)
         icalld1 = icalld1 + 1
c        resetFindpts = 0
c        added by keke
c        print *, 'before transfer nid: ', nid, '# particles: ', n
c        end added by keke
      endif
      
      scrt_timers(9) = dnekclock()
c     find particles in this rank, put into map
      call particles_in_nid_gpu(fptsmap,rfpts,lrf,ifpts,lif,nfpts,rpart
     $                     ,nr,ipart,ni,n)

c     lif is a 'block' size to know how many indexes to skip on next
c     jrc, jpt, and je0 store the find results
      scrt_timers(5) = dnekclock()
      call findpts(i_fp_hndl !  stride     !   call findpts( ihndl,
     $           , ifpts(jrc,1),lif        !   $             rcode,1,
     $           , ifpts(jpt,1),lif        !   &             proc,1,
     $           , ifpts(je0,1),lif        !   &             elid,1,
     $           , rfpts(jr ,1),lrf        !   &             rst,ndim,
     $           , rfpts(jd ,1),lrf        !   &             dist,1,
     $           , rfpts(jx ,1),lrf        !   &             pts(    1),1,
     $           , rfpts(jy ,1),lrf        !   &             pts(  n+1),1,
     $           , rfpts(jz ,1),lrf ,nfpts)    !   &             pts(2*n+1),1,n)
      scrt_timers(5) = dnekclock() - scrt_timers(5)
      pt_timers(5) = scrt_timers(5) + pt_timers(5)


      nmax = iglmax(n,1)
      if (nmax.gt.lpart) then
         if (nid.eq.0) write(6,1) nmax,lpart
    1    format('WARNING: Max number of particles:'
     $   i9,'.  Not moving because lpart =',i9,'.')
      else
         scrt_timers(6) = dnekclock()
c        copy rfpts and ifpts back into their repsected positions in rpart and ipart
         call update_findpts_info(rpart,nr,ipart,ni,n,rfpts,lrf
     $                       ,ifpts,lif,fptsmap,nfpts)
         scrt_timers(9) = dnekclock() - scrt_timers(9) - scrt_timers(5)
         pt_timers(9) = scrt_timers(9) + pt_timers(9)
c        Move particle info to the processor that owns each particle
c        using crystal router in log P time:

         jps = jai-1     ! Pointer to temporary proc id for swapping
         do i=1,n        ! Can't use jpt because it messes up particle info
            ipart(jps,i) = ipart(jpt,i)
         enddo

c        sends and receives particle information (updating n)
         call crystal_tuple_transfer(i_cr_hndl,n,lpart
     $              , ipart,ni,partl,nl,rpart,nr,jps)
c        Sort by element number - for improved local-eval performance
         call crystal_tuple_sort    (i_cr_hndl,n 
     $              , ipart,ni,partl,nl,rpart,nr,je0,1)
         pt_timers(6) = pt_timers(6) + dnekclock() - scrt_timers(6)
      endif

c     Interpolate (locally, if data is resident).
      scrt_timers(7) = dnekclock()
      call baryweights_findpts_eval_gpu(rpart,nr,ipart,ni,n)
      pt_timers(7) = pt_timers(7) + dnekclock() - scrt_timers(7)
      pt_timers(4) = pt_timers(4) + dnekclock() - scrt_timers(4)
      return
      end


c-----------------------------------------------------------------------
      subroutine update_stokes_particles(rpart,nr,ipart,ni,n)
c     Single step of Stokes particle dynamics
      include 'SIZE'
      include 'TOTAL'
      include 'CMTDATA'
      include 'CTIMER'

      common /myparth/ i_fp_hndl, i_cr_hndl
      common /myparts/ times(0:3),alpha(0:3),beta(0:3)
      real    pt_timers(10), scrt_timers(10)
      common /trackingtime/ pt_timers, scrt_timers
      real   xdrange(2,3)
      common /domainrange/ xdrange

      real    rpart(nr,n)
      integer ipart(ni,n)

      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid
      integer flagsend, flagreceive !used to inform all processor to stop when one particle move out of the domain


      jx0 = jx
      flagsend = 0
      flagreceive = 0

      scrt_timers(8) = dnekclock()
      call get_bdf_ext_coefs(beta,alpha,times)
c     Solve for velocity at time t^n
      do j=0,ndim-1
      do i=1,n
         rpart(ju3+j,i)=rpart(ju2+j,i)
         rpart(ju2+j,i)=rpart(ju1+j,i)
         rpart(ju1+j,i)=rpart(ju0+j,i)
         rpart(jv3+j,i)=rpart(jv2+j,i)
         rpart(jv2+j,i)=rpart(jv1+j,i)
         rpart(jv1+j,i)=rpart(jv0+j,i)
         rpart(jx3+j,i)=rpart(jx2+j,i)
         rpart(jx2+j,i)=rpart(jx1+j,i)
         rpart(jx1+j,i)=rpart(jx0+j,i)
      enddo
      enddo

      jst = jar ! Particle Stokes number = 1/tau
      do i=1,n
        s = rpart(jst,i)
        do j=0,ndim-1
          rhs = s*( alpha(1)*rpart(ju1+j,i)
     $            + alpha(2)*rpart(ju2+j,i)
     $            + alpha(3)*rpart(ju3+j,i)) + rpart(jf0,i)
     $        +     beta (1)*rpart(jv1+j,i)
     $        +     beta (2)*rpart(jv2+j,i)
     $        +     beta (3)*rpart(jv3+j,i)
          rpart(jv0+j,i) = rhs / (beta(0)+s) ! Implicit solve for v
          rhx = beta (1)*rpart(jx1+j,i)
     $        + beta (2)*rpart(jx2+j,i)
     $        + beta (3)*rpart(jx3+j,i) + rpart(jv0+j,i)
c          rpart(jx0+j,i) = rhx / beta(0)     ! Implicit solve for x
        enddo
c       rpart(jx, i) = rpart(jx, i) + rpart(jaa, i)*rpart(jad, i)
c       rpart(jy, i) = rpart(jy, i) + rpart(jab, i)*rpart(jad, i)
c       rpart(jz, i) = rpart(jz, i) + rpart(jac, i)*rpart(jad, i)

          rpart(jx, i) = rpart(jx, i) + (1.0/3)*rpart(jx, i)*DT
          rpart(jy, i) = rpart(jy, i)
          rpart(jz, i) = rpart(jz, i)
!         print *, 'nid: ', nid, 'i:', i, lglel(ipart(je0,i)+1),
!    $        rpart(jx, i), rpart(jy,i), 'DT: ', DT
      enddo

      do i=1,n
         if (rpart(jx,i) .gt. xdrange(2,1)) flagsend = flagsend + 1
         if (rpart(jx,i) .lt. xdrange(1,1)) flagsend = flagsend + 1
         if (rpart(jy,i) .gt. xdrange(2,2)) flagsend = flagsend + 1
         if (rpart(jy,i) .lt. xdrange(1,2)) flagsend = flagsend + 1
         if (rpart(jz,i) .gt. xdrange(2,3)) flagsend = flagsend + 1
         if (rpart(jz,i) .lt. xdrange(1,3)) flagsend = flagsend + 1
      enddo

      call igop (flagsend, flagreceive, '+  ', 1)
      if (flagreceive .ne. 0) then
         call exitt()
      endif

c     check if all particles are inside the domain:
c     For CMT-bone you can remove update_particle_location if confident
c     that particles will stay in domain.

c      call update_particle_location(nr,n,jx0,jx1,jx2,jx3,rpart) !function before
      call update_particle_location(1)  !function of new cmt-bone
      pt_timers(8) = pt_timers(8) + dnekclock() - scrt_timers(8)

c     Interpolate current velocity field at current position, to
c     be used in _next_ particle update step.
c      call compute_primitive_vars !function before
c      call interp_u_for_adv(rpart,nr,ipart,ni,n,vx,vy,vz) !function before

c     function of new cmt-bone
      call move_particles_inproc
      !call particles_solver_nearest_neighbor
      return
      end
c-----------------------------------------------------------------------
      subroutine update_particle_location(bc_part)
c     check if particles are outside domain
c     > if bc_part = 1 then it is periodic
c     > if bc_part = 0 then particles are killed
      include 'SIZE'
      include 'CMTDATA'
      parameter (lr=16*ldim,li=5+6)
      common  /cpartr/ rpart(lr,lpart) ! Minimal value of lr = 16*ndim
      common  /cparti/ ipart(li,lpart) ! Minimal value of li = 5
      common  /iparti/ n,nr,ni

      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid

      real  xdrange(2,3)
      common /domainrange/ xdrange
      integer bc_part,in_part(lpart), icount_p
      real rtmp(lr,lpart)
      integer itmp(li,lpart)

      jx0 = jx
      icount_p = 0


      do i=1,n
         in_part(i) = 0
         do j=0,ndim-1
            if (rpart(jx0+j,i).lt.xdrange(1,j+1))then
               if (bc_part .eq. 1) then
                  rpart(jx0+j,i) = xdrange(2,j+1) -
     &                             abs(xdrange(1,j+1) - rpart(jx0+j,i))
                  rpart(jx1+j,i) = xdrange(2,j+1) +
     &                             abs(xdrange(1,j+1) - rpart(jx1+j,i))
                  rpart(jx2+j,i) = xdrange(2,j+1) +
     &                             abs(xdrange(1,j+1) - rpart(jx2+j,i))
                  rpart(jx3+j,i) = xdrange(2,j+1) +
     &                             abs(xdrange(1,j+1) - rpart(jx3+j,i))
               elseif (bc_part .eq. 0) then
                  icount_p = icount_p + 1
                  in_part(i) = -1
               endif
            endif
            if (rpart(jx0+j,i).gt.xdrange(2,j+1))then
               if (bc_part .eq. 1) then
                  rpart(jx0+j,i) = xdrange(1,j+1) +
     &                             abs(rpart(jx0+j,i) - xdrange(2,j+1))
                  rpart(jx1+j,i) = xdrange(1,j+1) -
     &                             abs(rpart(jx1+j,i) - xdrange(2,j+1))
                  rpart(jx2+j,i) = xdrange(1,j+1) -
     &                             abs(rpart(jx2+j,i) - xdrange(2,j+1))
                  rpart(jx3+j,i) = xdrange(1,j+1) -
     &                             abs(rpart(jx3+j,i) - xdrange(2,j+1))
               elseif (bc_part .eq. 0) then
                  if (in_part(i) .ne. -1) then
                     icount_p = icount_p + 1
                     in_part(i) = -1
                  endif
               endif
            endif
         enddo
      enddo

      if (icount_p .ne. 0) then

      call rzero(rtmp,lr*lpart)
      call izero(itmp,li*lpart)

      nnew = n - icount_p
      icount_p = 0
      do i=1,n
         if (in_part(i).ne.-1) then
            icount_p = icount_p + 1
            do j=1,lr
               rtmp(j,icount_p) = rpart(j,i)
            enddo
            do j=1,li
               itmp(j,icount_p) = ipart(j,i)
            enddo
         endif
      enddo
      call rzero(rpart,lr*n)
      call izero(ipart,li*n)
      n = nnew
      call copy (rpart(1,1),rtmp(1,1),n*lr)
      call icopy(ipart(1,1),itmp(1,1),n*li)
      endif
      return
      end
c-----------------------------------------------------------------------

c-----------------------------------------------------------------------
      subroutine get_bdf_ext_coefs(beta,alpha,times)
      include 'SIZE'
      include 'TOTAL'

      real beta(0:3),alpha(0:3),times(0:3)
      real c(0:8)

      integer ilast,ncoef
      save    ilast,ncoef
      data    ilast,ncoef / -9 , 0 /

      do i=3,1,-1
         times(i)=times(i-1)
      enddo
      times(0) = time

      call rzero(beta ,4)
      call rzero(alpha,4)
      if (istep.ne.ilast) then
         ilast = istep
         ncoef = ncoef + 1
         ncoef = min(ncoef,3) ! Maximum 3rd order in time
      endif
      ncoefm1 = ncoef - 1

      call fd_weights_full(times(0),times(1),ncoefm1,0,alpha(1))
      call fd_weights_full(times(0),times(0),ncoef,1,c)
      do j=0,ncoef
         beta(j) = c(ncoef+1+j)
      enddo
      do j=1,ncoef
         beta(j) = -beta(j)  ! Change sign, for convenience
      enddo
      return
      end
c----------------------------------------------------------------------
      subroutine output_particles_new(rpart,nr,ipart,ni,n)
      include 'SIZE'

      real    rpart(nr,n)
      integer ipart(ni,n)

      real x(ldim,lpart),partv(lpart)
      common /scrns/ x_tmp(ldim+2,lpart),work(ldim+2,lpart)
     $              ,v_tmp(ldim+1,lpart)
      character*128 fname

c     common /ptpointers/ jrc,jpt,je0,jps,jai,nai,jr,jd,jx,jy,jz,jx1
c    $            ,jx2,jx3,jv0,jv1,jv2,jv3,ju0,ju1,ju2,ju3,jf0,jar,
c    $            jaa,jab,jac,jad,nar
      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid
      integer icalld
      save    icalld
      data    icalld  /-1/

      icalld = icalld+1
      if (nid.eq.0) then
        write(fname,1) icalld
 1      format('part',i5.5,'.3D')
        open(unit=72,file=fname)

        write(fname,2) icalld
 2      format('vel',i5.5,'.3D')
        open(unit=73,file=fname)
      endif

      npt_total = iglsum(n,1)
      npass = npt_total / lpart
      if (npt_total.gt.npass*lpart) npass = npass+1
      ilast = 0
      do ipass=1,npass
        mpart = min(lpart,npt_total-ilast)
        i0    = ilast
        i1    = i0 + mpart
        ilast = i1

        call rzero(x_tmp,(ldim+2)*lpart)
        call rzero(v_tmp,(ldim+1)*lpart)
        do ii=1,n ! loop over all particles
          if (i0.lt.ipart(jai,ii).and.ipart(jai,ii).le.i1) then
            i = ipart(jai,ii)-i0
            call copy(x_tmp(1,i),rpart(jx,ii),ldim)  ! Coordinates
            x_tmp(ldim+1,i) = ipart(jpt,ii) ! MPI rank
            x_tmp(ldim+2,i) = ipart(jai,ii) ! Part id 
            call copy(v_tmp(1,i),rpart(jv0,ii),ldim)  ! Velocity 
            v_tmp(ldim+1,i) = ipart(jai,ii) ! Part id 
          endif
        enddo
        call gop(x_tmp,work,'+  ',(ldim+2)*lpart)
        call gop(v_tmp,work,'+  ',(ldim+1)*lpart)
        if (nio.eq.0) write(72,3)((x_tmp(k,i),k=1,ldim+2),i=1,mpart)
        if (nio.eq.0) write(73,4)((v_tmp(k,i),k=1,ldim+1),i=1,mpart)
 3      format(1p5e17.9)
 4      format(1p4e17.9)
      enddo

      if (nio.eq.0) close(72)
      if (nio.eq.0) close(73)
      return
      end subroutine
c----------------------------------------------------------------------
      subroutine stokes_particles
      include 'SIZE'
      include 'TOTAL'
      include 'CTIMER'
c   This routine has 3 parts:
c
c   O init_stokes_particles 
c
c         o Initialize number of particles on each processor.
c
c         o They can all start on rank 0, if desired and if there is
c           sufficient memory.
c
c   O update_stokes_particles
c
c         o Particles are moved, subject to Stokes drag, using a
c           stable semi-implict BDFk/EXTk timestepper.  For timestep i,
c           k=min(i,3).
c
c         o If memory permits, particles will migrate to the processor 
c           holding their element and stay there till they move to another
c           processor.
c
c         o If memory does not permit, particles will stay where they
c           are, but will move back and forth for interpolation.
c           Thus, the particle update will correctly proceed but will
c           incur extra communication overhead.
c
c         o If starting with n particles on each processor, it is reasonable
c           to set lpart=2*n, so one may hold as many as 2n particles on any
c           given processor.
c
c   O output_stokes_particles
c
c         o At the moment, this is a really stupid hack.  Output requirements
c           differ by orders of magnitude from one application to the next, so
c           we do not yet have a determined output format.  This is more or less
c           left to the user.
c
c         o Any serious particle tracking will want the output in binary, using
c           parallel I/O.
c
c         o Currently, there is no restart capability, but it would be simple
c           enough to dump ipart() and rpart() arrays for each processor in 
c           order to checkpoint.
c
c   O Data:
c
c         There are two arrays, ipart(li,lpart) and rpart(li,lpart)
c
c         o ipart(*,i) holds vital pointer information for the ith particle 
c                      on the current node.  
c
c              - It is easy to add auxiliary pointers (tags), such as
c                the step number in which the particle was added to the
c                list, the particle id (local or global, but less than 
c                1 billion), etc.
c
c              - To adduxiliary integer data, just increase the parameter li
c                and start to fill in the integer locations in the range
c
c                ipart(jai:ni,i)  i=1,2,...,n
c
c                jai is the pointer to auxiliary integers
c
c         o rpart(*,i) holds real values associated with advancement of the
c                      ith particle on the current node.  
c
c              - Values stored here include saved values of position and
c                velocity used in BDFk/EXTk, the Stokes number, etc.
c
c              - You can also store different times at which the particle positions
c                are updated in order to support variable timestepping.
c
c         o Both arrays are exchanged via the crystal router tuple call.
      parameter (lr=16*ldim,li=5+6)
      common  /cpartr/ rpart(lr,lpart) ! Minimal value of lr = 16*ndim
      common  /cparti/ ipart(li,lpart) ! Minimal value of li = 5
      common  /iparti/ n,nr,ni

      real    pt_timers(10), scrt_timers(10)
      common /trackingtime/ pt_timers, scrt_timers

c     lr is the limit (pre-allocated static size) for real, li is the limit for integer
      scrt_timers(3) = dnekclock()
      call update_stokes_particles (rpart,nr,ipart,ni,n)
c     print *, "end CPU update particles"
      pt_timers(3) = pt_timers(3) + dnekclock() - scrt_timers(3)

C      if(mod(istep,iostep).eq.0.or.istep.eq.1)
C     $       call output_particles_new       (rpart,nr,ipart,ni,n)
      return
      end
!-----------------------------------------------------------------------
      subroutine usrflt(rmult)
      include 'SIZE'
      real rmult(nx1)
      real alpfilt
      integer sfilt, kut
      real eta, etac
      rmult=1.0
      alpfilt=36.0 ! H&W 5.3
      kut=6
      sfilt=8
      etac=real(kut)/real(nx1)
      do i=kut,nx1
         eta=real(i)/real(nx1)
         rmult(i)=exp(-alpfilt*((eta-etac)/(1.0-etac))**sfilt)
      enddo
      return
      end subroutine usrflt

c-----------------------------------------------------------------------
      subroutine particles_in_nid_gpu(fptsmap,rfpts,nrf,ifpts,nif,nfpts
     &                            ,rpart,nr,ipart,ni,n)
      include 'SIZE'

      real    rpart(nr,n)
      integer ipart(ni,n)

      real    rfpts(nrf,*)
      integer ifpts(nif,*),fptsmap(*)

      real   xerange(2,3,lelt)
      common /elementrange/ xerange

      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid

c     nfpts - number of points advected out of this rank's spatial domain
      nfpts = 0
      call particles_in_nid_wrapper(fptsmap, rfpts, ifpts, rpart, ipart
     $            ,xerange, nrf, nif, nfpts, nr, ni, n, lpart, nelt,
     $            jx, jy, jz, je0, jrc, jpt, jd, jr, nid)
      return
      end subroutine

c-----------------------------------------------------------------------
c     subroutine update_findpts_info(rpart,nr,ipart,ni,n,rfpts,nrf
c    $                         ,ifpts,nif,fptsmap,nfpts)
      subroutine update_findpts_info(rfpts,nrf
     $                         ,ifpts,nif,fptsmap,nfpts)  !new one
      include 'SIZE'
c     real    rpart(nr,n)
c     integer ipart(ni,n)

      parameter (lr=16*ldim,li=5+6)
      common  /cpartr/ rpart(lr,lpart) ! Minimal value of lr = 16*ndim+1
      common  /cparti/ ipart(li,lpart) ! Minimal value of li = 5
      common  /iparti/ n,nr,ni     !new one

      real    rfpts(nrf,nfpts)
      integer ifpts(nif,nfpts),fptsmap(nfpts)
      do ifp = 1,nfpts
         call copy(rpart(1,fptsmap(ifp)),rfpts(1,ifp),nrf)
         call icopy(ipart(1,fptsmap(ifp)),ifpts(1,ifp),nif)
      enddo
      return
      end subroutine
c-----------------------------------------------------------------------
      subroutine baryweights
      include 'SIZE' 
      include 'INPUT' 
c
c     calculates the barycentric lagrange weights
c
      common /BARYPARAMS/ xgll, ygll, zgll, wxgll, wygll, wzgll
      real xgll(lx1), ygll(ly1), zgll(lz1),
     >     wxgll(lx1), wygll(ly1), wzgll(lz1)
      real pi
      parameter (pi = 4.0*atan(1.0))

c     get gll points in all directions (here I did cheb. instead)
c     using command in Nek
      call zwgll(xgll,wxgll,lx1)
      call zwgll(ygll,wygll,ly1)
      call rone(zgll,lz1)
      if(if3d) call zwgll(zgll,wzgll,lz1)
c     set all weights to ones first
      call rone(wxgll,lx1)
      call rone(wygll,ly1)
      call rone(wzgll,lz1)
c     begin weight calculations
      do j=1,lx1
         do k=1,lx1
            if (j .NE. k) then
               wxgll(j) = wxgll(j)/(xgll(j) - xgll(k))
            endif
         enddo
      enddo

      do j=1,ly1
         do k=1,ly1
            if (j .NE. k) then
               wygll(j) = wygll(j)/(ygll(j) - ygll(k))
            endif
         enddo
      enddo

      do j=1,lz1
         do k=1,lz1
            if (j .NE. k) then
               wzgll(j) = wzgll(j)/(zgll(j) - zgll(k))
            endif
         enddo
      enddo
      if (nio.eq.0) then
         do i=1,nx1
            write(501,*)xgll(i),wxgll(i) 
            write(502,*)ygll(i),wygll(i) 
            write(503,*)zgll(i),wzgll(i) 
         enddo
      endif
      return 
      end subroutine baryweights
c----------------------------------------------------------------
      subroutine baryinterp(field,pofx) !new one
c     used for 3d interpolation only
      include 'SIZE'
      common /BARRYREP/ rep, bot
      real              rep(lx1,ly1,lz1), bot
      real field(1),pofx,top

      top = 0.00
      nxyz = nx1*ny1*nz1

      do i=1,nxyz
         top =  top + rep(i,1,1)*field(i)
      enddo
      pofx = top/bot

      return
      end

c-----barycentric interpolation ---------------------------------
      subroutine baryinterp_old(x,y,z,nfields,fields,p) !old code
      include 'SIZE'
      
      integer nfields
      common /BARYPARAMS/ xgll, ygll, zgll, wxgll, wygll, wzgll
      real xgll(lx1), ygll(ly1), zgll(lz1),
     >     wxgll(lx1), wygll(ly1), wzgll(lz1)
      real      top(nfields), bot(nfields), p(nfields)
      real x, y, z, rep
      real fields(nx1,ny1,nz1,nfields)

      call rzero(top,nfields)
      call rzero(bot,nfields)

      do k=1,lz1
         repz = wzgll(k)/(z-zgll(k))
         do j=1,ly1
            repy = repz*wygll(j)/(y-ygll(j))
            do i=1,lx1
               repx = repy*wxgll(i)/(x-xgll(i))
               do l=1,nfields
                  top(l) = top(l) + repx*fields(i,j,k,l)
                  bot(l) = bot(l) + repx
               enddo
            enddo
         enddo
      enddo

      do l=1,nfields 
         p(l) = top(l)/bot(l)
      enddo
      return 
      end

c-----------------------------------------------------------------------
      subroutine baryweights_findpts_eval_gpu(rpart,nr,ipart,ni,n)
      include 'SIZE'
      include 'INPUT'
      include 'SOLN'
      real    rpart(nr,n)
      integer ipart(ni,n)

      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid      

      common /BARYPARAMS/ xgll, ygll, zgll, wxgll, wygll, wzgll
      real xgll(lx1), ygll(ly1), zgll(lz1),
     >     wxgll(lx1), wygll(ly1), wzgll(lz1)


      common /BARRYREP/ rep, bot
      real              rep(lx1,ly1,lz1), bot
      
      call baryweights_evalwrapper(rpart, ipart, vx, vy, vz, rep,
     >     xgll, ygll,zgll, wxgll, wygll, wzgll, jr,
     >     je0, ju0, lx1, n, nr, ni, nelt)
       
      return
      end subroutine

c-----------------------------------------------------------------------
      subroutine baryweights_findpts_eval(rpart,nr,ipart,ni,n)
      include 'SIZE'
      include 'INPUT'
      include 'SOLN'
      real    rpart(nr,n)
      integer ipart(ni,n)

      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid

      common /BARRYREP/ rep, bot
      real              rep(lx1,ly1,lz1), bot
      nxyz = nx1*ny1*nz1
      if (if3d) then
        do i=1,n
           call init_baryinterp(rpart(jr,i),rpart(jr+1,i),rpart(jr+2,i))
           ie  =  ipart(je0,i) + 1
           call baryinterp_new(vx(1,1,1,ie),rpart(ju0,i))
           call baryinterp_new(vy(1,1,1,ie),rpart(ju0+1,i))
           call baryinterp_new(vz(1,1,1,ie),rpart(ju0+2,i))
        enddo
      else
        do i=1,n
           call init_baryinterp(rpart(jr,i),rpart(jr+1,i),1.0)
           ie  =  ipart(je0,i) + 1
           call baryinterp_new(vx(1,1,1,ie),rpart(ju0,i))
           call baryinterp_new(vy(1,1,1,ie),rpart(ju0+1,i))
        enddo
      endif
      return
      end subroutine
c-----------------------------------------------------------------------
      subroutine init_baryinterp(x,y,z) !new
c     used for 3d interpolation only
      include 'SIZE'
      common /BARYPARAMS/ xgll, ygll, zgll, wxgll, wygll, wzgll
      real xgll(lx1), ygll(ly1), zgll(lz1),
     >     wxgll(lx1), wygll(ly1), wzgll(lz1)
      common /BARRYREP/ rep, bot
      real              rep(lx1,ly1,lz1), bot

      real x, y, z, repy, repz,repx,diff
      real bwgtx(lx1),bwgty(ly1),bwgtz(lz1)
c     main loop, but notice bwgtz, bwgtx, bwgty could be NaN if
c     interpolated point is on a grid location. Need to fix, but
c     is currently very robust. I THINK I fixed it......3/14/16 DZ
      bot= 0.00
      do k=1,nz1
         diff = z - zgll(k)
           if (abs(diff) .le. 1E-16) diff = sign(1E-16,diff)
         bwgtz(k) = wzgll(k)/diff
      enddo
      do i=1,nx1
         diff = x - xgll(i)
           if (abs(diff) .le. 1E-16) diff = sign(1E-16,diff)
         bwgtx(i) = wxgll(i)/diff
      enddo
      do j=1,ny1
         diff = y-ygll(j)
           if (abs(diff) .le. 1E-16) diff = sign(1E-16,diff)
         bwgty(j) = wygll(j)/diff
      enddo
      do k=1,nz1
      do j=1,ny1
         repdum = bwgty(j)*bwgtz(k)
      do i=1,nx1
         rep(i,j,k) =  repdum* bwgtx(i)
         bot        =  bot + rep(i,j,k)
      enddo
      enddo
      enddo
      return
      end

c-----------------------------------------------------------------------
      subroutine init_baryinterp_previous(x,y,z) !old code, not use
      include 'SIZE'
      common /BARYPARAMS/ xgll, ygll, zgll, wxgll, wygll, wzgll
      real xgll(lx1), ygll(ly1), zgll(lz1),
     >     wxgll(lx1), wygll(ly1), wzgll(lz1)
      common /BARRYREP/ rep, bot
      real              rep(lx1,ly1,lz1), bot

      real x, y, z, repy, repz,repx
      real bwgtx(lx1),bwgty(ly1),bwgtz(lz1)

      bot= 0.00
      do k=1,nz1
         bwgtz(k) = wzgll(k)/(z-zgll(k))
      enddo
      do i=1,nx1
         bwgtx(i) = wxgll(i)/(x-xgll(i))
      enddo 
      do j=1,ny1
         bwgty(j) = wygll(j)/(y-ygll(j))
      enddo
      do k=1,nz1
      do j=1,ny1
         repdum = bwgty(j)*bwgtz(k)
      do i=1,nx1
         rep(i,j,k) =  repdum* bwgtx(i)
         bot        =  bot + rep(i,j,k)
      enddo
      enddo
      enddo 
      return
      end subroutine
c-----------------------------------------------------------------------
      subroutine baryinterp_new(field,pofx) !old one
      include 'SIZE'

      common /BARRYREP/ rep, bot
      real              rep(lx1,ly1,lz1), bot
      real field(1),pofx,top

      top = 0.00
      nxyz = nx1*ny1*nz1
      do i=1,nxyz
         top =  top + rep(i,1,1)*field(i)
      enddo
      pofx = top/bot
      return
      end subroutine
c-----------------------------------------------------------------------
      FUNCTION ran2(idum)
      INTEGER idum,IM1,IM2,IMM1,IA1,IA2,IQ1,IQ2,IR1,IR2,NTAB,NDIV 
      REAL ran2,AM,EPS,RNMX
      PARAMETER (IM1=2147483563,IM2=2147483399,AM=1./IM1,IMM1=IM1-1,
     $        IA1=40014,IA2=40692,IQ1=53668,IQ2=52774,IR1=12211,
     $        IR2=3791,NTAB=32,NDIV=1+IMM1/NTAB,EPS=1.2e-7,RNMX=1.-EPS)
c Long period (> 2 ! 1018 ) random number generator of L’Ecuyer with 
c Bays-Durham shuffle and added safeguards. Returns a uniform random deviate 
c between 0.0 and 1.0 (exclusive of the endpoint values). 
c Call with idum a negative integer to initialize; thereafter, do not alter 
c idum between successive deviates in a sequence. RNMX should approximate the 
c largest floating value that is less than 1.
      INTEGER idum2,j,k,iv(NTAB),iy
      SAVE iv,iy,idum2
      DATA idum2/123456789/, iv/NTAB*0/, iy/0/
      if (idum.le.0) then 
         idum1=max(-idum,1) 
         idum2=idum1
         do j=NTAB+8,1,-1
            k=idum1/IQ1
            idum1=IA1*(idum1-k*IQ1)-k*IR1 
            if (idum1.lt.0) idum1=idum1+IM1 
            if (j.le.NTAB) iv(j)=idum1
         enddo
         iy=iv(1) 
      endif
      k=idum1/IQ1 
      idum1=IA1*(idum1-k*IQ1)-k*IR1
      if (idum1.lt.0) idum1=idum1+IM1 
      k=idum2/IQ2 
      idum2=IA2*(idum2-k*IQ2)-k*IR2 
      if (idum2.lt.0) idum2=idum2+IM2 
      j=1+iy/NDIV
      iy=iv(j)-idum2
      iv(j)=idum1 
      if(iy.lt.1)iy=iy+IMM1 
      ran2=min(AM*iy,RNMX)
      return
      END
c-----------------------------------------------------------------------
      subroutine interp_u_for_adv(rpart,nr,ipart,ni,n,ux,uy,uz)
c     Interpolate fluid velocity at current xyz points and move
c     data to the processor that owns the points.
c     Input:    n = number of points on this processor
c     Output:   n = number of points on this processor after the move
c     Code checks for n > lpart and will not move data if there
c     is insufficient room.
      include 'SIZE'
      include 'TOTAL'
      include 'CTIMER'

      common /nekmpi/ mid,mp,nekcomm,nekgroup,nekreal
      common /myparth/ i_fp_hndl, i_cr_hndl

      real    pt_timers(10), scrt_timers(10)
      common /trackingtime/ pt_timers, scrt_timers

      real    rpart(nr,n),ux(1),uy(1),uz(1)
      integer ipart(ni,n)

      parameter (lrf=4+ldim,lif=5+1)
      real               rfpts(lrf,lpart)
      common /fptspartr/ rfpts
      integer            ifpts(lif,lpart),fptsmap(lpart)
      common /fptsparti/ ifpts,fptsmap

      common /ptpointers/ jrc,jpt,je0,jps,jpid1,jpid2,jpid3,jpnn,jai
     >               ,nai,jr,jd,jx,jy,jz,jx1,jx2,jx3,jv0,jv1,jv2,jv3
     >               ,ju0,ju1,ju2,ju3,jf0,jar,jaa,jab,jac,jad,nar,jpid

      integer icalld1
      save    icalld1
      data    icalld1 /0/

      logical partl         ! This is a dummy placeholder, used in cr()
      nl = 0                ! No logicals exchanged

      scrt_timers(4) = dnekclock()
      call interp_comm_part()

      scrt_timers(9) = dnekclock()

!     find particles in this rank, put into map
      call particles_in_nid(fptsmap,rfpts,lrf,ifpts,lif,nfpts,rpart,nr
     $                     ,ipart,ni,n)

c     lif is a 'block' size to know how many indexes to skip on next
c     jrc, jpt, and je0 store the find results
      scrt_timers(5) = dnekclock()
      call findpts(i_fp_hndl !  stride     !   call findpts( ihndl,
     $           , ifpts(jrc,1),lif        !   $             rcode,1,
     $           , ifpts(jpt,1),lif        !   &             proc,1,
     $           , ifpts(je0,1),lif        !   &             elid,1,
     $           , rfpts(jr ,1),lrf        !   &             rst,ndim,
     $           , rfpts(jd ,1),lrf        !   &             dist,1,
     $           , rfpts(jx ,1),lrf        !   &             pts(    1),1,
     $           , rfpts(jy ,1),lrf        !   &             pts(  n+1),1,
     $           , rfpts(jz ,1),lrf ,nfpts)    !   &             pts(2*n+1),1,n)      scrt_timers(5) = dnekclock() - scrt_timers(5)
      pt_timers(5) = scrt_timers(5) + pt_timers(5)


      nmax = iglmax(n,1)
      if (nmax.gt.lpart) then
         if (nid.eq.0) write(6,1) nmax,lpart
    1    format('WARNING: Max number of particles:'
     $   i9,'.  Not moving because lpart =',i9,'.')
      else
         scrt_timers(6) = dnekclock()
!        copy rfpts and ifpts back into their repsected positions in rpart and ipart
         call update_findpts_info(rpart,nr,ipart,ni,n,rfpts,lrf
     $                       ,ifpts,lif,fptsmap,nfpts)
         scrt_timers(9) = dnekclock() - scrt_timers(9) - scrt_timers(5)
         pt_timers(9) = scrt_timers(9) + pt_timers(9)
!        Move particle info to the processor that owns each particle
!        using crystal router in log P time:

         jps = jai-1     ! Pointer to temporary proc id for swapping
         do i=1,n        ! Can't use jpt because it messes up particle info
            ipart(jps,i) = ipart(jpt,i)
         enddo

!        sends and receives particle information (updating n)
         call crystal_tuple_transfer(i_cr_hndl,n,lpart
     $              , ipart,ni,partl,nl,rpart,nr,jps)
!        Sort by element number - for improved local-eval performance
         call crystal_tuple_sort    (i_cr_hndl,n
     $              , ipart,ni,partl,nl,rpart,nr,je0,1)
         pt_timers(6) = pt_timers(6) + dnekclock() - scrt_timers(6)
      endif

!     Interpolate (locally, if data is resident).
      scrt_timers(7) = dnekclock()
      call baryweights_findpts_eval(rpart,nr,ipart,ni,n)
      pt_timers(7) = pt_timers(7) + dnekclock() - scrt_timers(7)
      pt_timers(4) = pt_timers(4) + dnekclock() - scrt_timers(4)
      return
      end
!-----------------------------------------------------------------------

c
c automatically added by makenek
      subroutine usrsetvert(glo_num,nel,nx,ny,nz) ! to modify glo_num
      integer*8 glo_num(1)
      return
      end
c
c automatically added by makenek
      subroutine cmt_switch ! to set IFCMT logical flag
      include 'SIZE'
      include 'INPUT'
      IFCMT=.true.
      return
      end
