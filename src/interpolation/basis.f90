#include "hopest_f.h"

MODULE MODH_Basis
!===================================================================================================================================
! Add comments please!
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
SAVE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part
! ----------------------------------------------------------------------------------------------------------------------------------
! Public Part
! ----------------------------------------------------------------------------------------------------------------------------------
INTERFACE BuildLegendreVdm
   MODULE PROCEDURE BuildLegendreVdm
END INTERFACE

INTERFACE InitializeVandermonde
   MODULE PROCEDURE InitializeVandermonde
END INTERFACE

INTERFACE ChebyshevGaussNodesAndWeights
   MODULE PROCEDURE ChebyshevGaussNodesAndWeights
END INTERFACE

INTERFACE ChebyGaussLobNodesAndWeights
   MODULE PROCEDURE ChebyGaussLobNodesAndWeights
END INTERFACE

INTERFACE LegendreGaussNodesAndWeights
   MODULE PROCEDURE LegendreGaussNodesAndWeights
END INTERFACE

INTERFACE LegGaussLobNodesAndWeights
   MODULE PROCEDURE LegGaussLobNodesAndWeights
END INTERFACE

INTERFACE LegendrePolynomialAndDerivative
   MODULE PROCEDURE LegendrePolynomialAndDerivative
END INTERFACE

INTERFACE PolynomialDerivativeMatrix
   MODULE PROCEDURE PolynomialDerivativeMatrix
END INTERFACE

INTERFACE BarycentricWeights 
   MODULE PROCEDURE BarycentricWeights
END INTERFACE

INTERFACE LagrangeInterpolationPolys
   MODULE PROCEDURE LagrangeInterpolationPolys
END INTERFACE

INTERFACE GetNodesAndWeights
   MODULE PROCEDURE GetNodesAndWeights
END INTERFACE

INTERFACE GetVandermonde
   MODULE PROCEDURE GetVandermonde
END INTERFACE


PUBLIC::BuildLegendreVdm
PUBLIC::InitializeVandermonde
PUBLIC::LegGaussLobNodesAndWeights
PUBLIC::LegendreGaussNodesAndWeights
PUBLIC::ChebyshevGaussNodesAndWeights
PUBLIC::ChebyGaussLobNodesAndWeights
PUBLIC::LegendrePolynomialAndDerivative
PUBLIC::PolynomialDerivativeMatrix
PUBLIC::BarycentricWeights
PUBLIC::LagrangeInterpolationPolys
PUBLIC::GetNodesAndWeights
PUBLIC::GetVandermonde


!===================================================================================================================================


CONTAINS


SUBROUTINE buildLegendreVdm(N_In,xi_In,Vdm_Leg,sVdm_Leg)
!===================================================================================================================================
! build a 1D Vandermonde matrix using the lagrange basis functions of degree
! N_In, evaluated at the interpolation points xi_Out
!===================================================================================================================================
! MODULES
USE MODH_Globals,ONLY:abort
USE MODH_PreProc
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN) :: N_In
REAL,INTENT(IN)    :: xi_In(0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)   :: Vdm_Leg(0:N_In,0:N_In),sVdm_Leg(0:N_In,0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER            :: i,j
REAL               :: dummy 
REAL               :: wBary_Loc(0:N_In)
REAL               :: xGauss(0:N_In),wGauss(0:N_In)
!===================================================================================================================================
CALL BarycentricWeights(N_In,xi_in,wBary_loc)
! Compute first the inverse (by projection)
CALL LegendreGaussNodesAndWeights(N_In,xGauss,wGauss)
!Vandermonde on xGauss
DO i=0,N_In
  DO j=0,N_In
    CALL LegendrePolynomialAndDerivative(j,xGauss(i),Vdm_Leg(i,j),dummy) 
  END DO !i
END DO !j
Vdm_Leg=TRANSPOSE(Vdm_Leg)
DO j=0,N_In
  Vdm_Leg(:,j)=Vdm_Leg(:,j)*wGauss(j)
END DO
!evaluate nodal basis (depends on NodeType, for Gauss: unity matrix)
CALL InitializeVandermonde(N_In,N_In,wBary_Loc,xi_In,xGauss,sVdm_Leg)
sVdm_Leg=MATMUL(Vdm_Leg,sVdm_Leg)
!compute the Vandermonde on xGP (Depends on NodeType)
DO i=0,N_In
  DO j=0,N_In
    CALL LegendrePolynomialAndDerivative(j,xi_In(i),Vdm_Leg(i,j),dummy) 
  END DO !i
END DO !j
!check (Vdm_Leg)^(-1)*Vdm_Leg := I 
dummy=SUM((ABS(MATMUL(sVdm_Leg,Vdm_Leg)))-(N_In+1))
IF(dummy.GT. PP_RealTolerance) &
  CALL abort(__STAMP__,&
  'problems in MODAL<->NODAL Vandermonde ',999,dummy)

END SUBROUTINE buildLegendreVdm


SUBROUTINE InitializeVandermonde(N_In,N_Out,wBary_In,xi_In,xi_Out,Vdm)
!===================================================================================================================================
! build a 1D Vandermonde matrix using the lagrange basis functions of degree
! N_In, evaluated at the interpolation points xi_Out
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN) :: N_In,N_Out
REAL,INTENT(IN)    :: xi_In(0:N_In)
REAL,INTENT(IN)    :: xi_Out(0:N_Out)
REAL,INTENT(IN)    :: wBary_In(0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)   :: Vdm(0:N_Out,0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER            :: iXi
!===================================================================================================================================
DO iXi=0,N_Out
  CALL LagrangeInterpolationPolys(xi_Out(iXi),N_In,xi_In,wBary_In,Vdm(iXi,:)) !l(0:N_In)
END DO
END SUBROUTINE InitializeVandermonde



SUBROUTINE LegendrePolynomialAndDerivative(N_in,x,L,Lder)
!===================================================================================================================================
! algorithm 22, Kopriva
! evaluate the Legendre polynomial L_N and its derivative at position x[-1,1] 
! recursive algorithm using the N_in-1 N_in-2 Legendre polynomials
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in   ! polynomial degree, (N+1) CLpoints 
REAL,INTENT(IN)    :: x      ! coordinate value in the interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: L,Lder ! L_N(xi), d/dxi L_N(xi)
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER :: iLegendre
REAL    :: L_Nm1,L_Nm2 ! L_{N_in-2},L_{N_in-1}
REAL    :: Lder_Nm1,Lder_Nm2 ! Lder_{N_in-2},Lder_{N_in-1}
!===================================================================================================================================
IF(N_in .EQ. 0)THEN
  L=1.
  Lder=0.
ELSEIF(N_in .EQ. 1) THEN
  L=x
  Lder=1.
ELSE ! N_in > 1
  L_Nm2=1.
  L_Nm1=x
  Lder_Nm2=0.
  Lder_Nm1=1.
  DO iLegendre=2,N_in
    L=(REAL(2*iLegendre-1)*x*L_Nm1 - REAL(iLegendre-1)*L_Nm2)/REAL(iLegendre)
    Lder=Lder_Nm2 + REAL(2*iLegendre-1)*L_Nm1
    L_Nm2=L_Nm1
    L_Nm1=L
    Lder_Nm2=Lder_Nm1
    Lder_Nm1=Lder
  END DO !iLegendre=2,N_in
END IF ! N_in
!normalize
L=L*SQRT(REAL(N_in)+0.5)
Lder=Lder*SQRT(REAL(N_in)+0.5)
END SUBROUTINE LegendrePolynomialAndDerivative




SUBROUTINE ChebyshevGaussNodesAndWeights(N_in,xGP,wGP)
!===================================================================================================================================
! algorithm 27, Kopriva
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in       ! polynomial degree, (N_in+1) CLpoints 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)          :: xGP(0:N_in)  ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(OUT),OPTIONAL :: wGP(0:N_in)  ! Gausspoint weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER                   :: iGP
!===================================================================================================================================
DO iGP=0,N_in
  xGP(iGP)=-cos((2*iGP+1)/(2*REAL(N_in)+2)*ACOS(-1.))
END DO
IF(PRESENT(wGP))THEN
  DO iGP=0,N_in
    wGP(iGP)=ACOS(-1.)/REAL(N_in+1)
  END DO
END IF
END SUBROUTINE ChebyshevGaussNodesAndWeights



SUBROUTINE ChebyGaussLobNodesAndWeights(N_in,xGP,wGP)
!===================================================================================================================================
! algorithm 27, Kopriva
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in       ! polynomial degree, (N_in+1) CLpoints 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)          :: xGP(0:N_in)  ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(OUT),OPTIONAL :: wGP(0:N_in)  ! Gausspoint weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: iGP
!===================================================================================================================================
DO iGP=0,N_in
  xGP(iGP)=-COS(iGP/REAL(N_in)*ACOS(-1.))
END DO
IF(PRESENT(wGP))THEN
  DO iGP=0,N_in
    wGP(iGP)=ACOS(-1.)/REAL(N_in)
  END DO
  wGP(0)=wGP(0)*0.5
  wGP(N_in)=wGP(N_in)*0.5
END IF
END SUBROUTINE ChebyGaussLobNodesAndWeights



SUBROUTINE LegendreGaussNodesAndWeights(N_in,xGP,wGP)
!===================================================================================================================================
! algorithm 23, Kopriva
! starting with Chebychev point positions, a Newton method is used to find the roots 
! of the Legendre Polynomial L_(N_in+1), which are the positions of Gausspoints
! uses LegendrePolynomialAndDerivative subroutine
!===================================================================================================================================
!MODULES
USE MODH_Globals
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in              ! polynomial degree, (N_in+1) Gausspoints 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)          :: xGP(0:N_in)       ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(OUT),OPTIONAL :: wGP(0:N_in)       ! Gausspoint weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER                   :: iGP,iter,nIter
REAL                      :: Tol            ! tolerance for Newton iteration
REAL                      :: L_Np1,Lder_Np1 ! L_{N_in+1},Lder_{N_in+1}
REAL                      :: dx             ! Newton step
REAL                      :: cheb_tmp       ! temporary variable for evaluation of chebychev node positions
!===================================================================================================================================
IF(N_in .EQ. 0) THEN
  xGP=0.
  IF(PRESENT(wGP))wGP=2.
  RETURN
ELSEIF(N_in.EQ.1)THEN
  xGP(0)=-sqrt(1./3.)
  xGP(N_in)=-xGP(0)
  IF(PRESENT(wGP))wGP=1.
  RETURN
ELSE ! N_in>1
  Tol=1.E-15
  nIter=10 
  cheb_tmp=2.*atan(1.)/REAL(N_in+1) ! pi/(2N+2)
  DO iGP=0,(N_in+1)/2-1 !since points are symmetric, only left side is computed
    xGP(iGP)=-cos(cheb_tmp*REAL(2*iGP+1)) !initial guess
    ! Newton iteration
    DO iter=0,nIter
      CALL LegendrePolynomialAndDerivative(N_in+1,xGP(iGP),L_Np1,Lder_Np1)
      dx=-L_Np1/Lder_Np1
      xGP(iGP)=xGP(iGP)+dx
      IF(abs(dx).LT.Tol*abs(xGP(iGP))) EXIT
    END DO ! iter
    IF(iter.GT.nIter) THEN
      SWRITE(*,*) 'maximum iteration steps >10 in Newton iteration for Legendre Gausspoint'
      xGP(iGP)=-cos(cheb_tmp*REAL(2*iGP+1)) !initial guess
      ! Newton iteration
      DO iter=0,nIter
        !SWRITE(*,*)iter,xGP(iGP)    !DEBUG  
        CALL LegendrePolynomialAndDerivative(N_in+1,xGP(iGP),L_Np1,Lder_Np1)
        dx=-L_Np1/Lder_Np1
        xGP(iGP)=xGP(iGP)+dx
        IF(abs(dx).LT.Tol*abs(xGP(iGP))) EXIT
      END DO !iter
      CALL abort(__STAMP__,&
                 'Code stopped!',999,999.)
    END IF ! (iter.GT.nIter)
    CALL LegendrePolynomialAndDerivative(N_in+1,xGP(iGP),L_Np1,Lder_Np1)
    xGP(N_in-iGP)=-xGP(iGP)
    IF(PRESENT(wGP))THEN
      !wGP(iGP)=2./((1.-xGP(iGP)*xGP(iGP))*Lder_Np1*Lder_Np1) !if Legendre not normalized
      wGP(iGP)=(2.*N_in+3)/((1.-xGP(iGP)*xGP(iGP))*Lder_Np1*Lder_Np1)
      wGP(N_in-iGP)=wGP(iGP)
    END IF
  END DO !iGP
END IF ! N_in
IF(mod(N_in,2) .EQ. 0) THEN
  xGP(N_in/2)=0.
  CALL LegendrePolynomialAndDerivative(N_in+1,xGP(N_in/2),L_Np1,Lder_Np1)
  !IF(PRESENT(wGP))wGP(N_in/2)=2./(Lder_Np1*Lder_Np1) !if Legendre not normalized
  IF(PRESENT(wGP))wGP(N_in/2)=(2.*N_in+3)/(Lder_Np1*Lder_Np1)
END IF ! (mod(N_in,2) .EQ. 0)
END SUBROUTINE LegendreGaussNodesAndWeights



SUBROUTINE qAndLEvaluation(N_in,x,q,qder,L)
!===================================================================================================================================
! algorithm 24, Kopriva
! evaluate the polynomial q=L_{N_in+1}-L_{N_in-1} and its derivative at position x[-1,1] 
! recursive algorithm using the N_in-1 N_in-2 Legendre polynomials
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in                               ! polynomial degree
REAL,INTENT(IN)    :: x                               ! coordinate value in the interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: L,q,qder                        ! L_N(xi), d/dxi L_N(xi)
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: iLegendre
REAL               :: L_Nm1,L_Nm2                     ! L_{N_in-2},L_{N_in-1}
REAL               :: Lder,Lder_Nm1,Lder_Nm2          ! Lder_{N_in-2},Lder_{N_in-1}
!===================================================================================================================================
L_Nm2=1.
L_Nm1=x
Lder_Nm2=0.
Lder_Nm1=1.
DO iLegendre=2,N_in
  L=(REAL(2*iLegendre-1)*x*L_Nm1 - REAL(iLegendre-1)*L_Nm2)/REAL(iLegendre)
  Lder=Lder_Nm2 + REAL(2*iLegendre-1)*L_Nm1
  L_Nm2=L_Nm1
  L_Nm1=L
  Lder_Nm2=Lder_Nm1
  Lder_Nm1=Lder
END DO ! iLegendre
q=REAL(2*N_in+1)/REAL(N_in+1)*(x*L -L_Nm2) !L_{N_in+1}-L_{N_in-1} !L_Nm2 is L_Nm1, L_Nm1 was overwritten!
qder= REAL(2*N_in+1)*L             !Lder_{N_in+1}-Lder_{N_in-1} 
END SUBROUTINE qAndLEvaluation



SUBROUTINE LegGaussLobNodesAndWeights(N_in,xGP,wGP)
!===================================================================================================================================
! algorithm 25, Kopriva
! starting with initial guess by Parter Relation, a Newton method is used to find the roots 
! of the Legendre Polynomial Lder_(N_in), which are the positions of Gausspoints
! uses qAndLEvaluation subroutine
!===================================================================================================================================
! MODULES
USE MODH_Globals
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in                ! polynomial degree (N_in+1) Gausspoints 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)          :: xGP(0:N_in)         ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(OUT),OPTIONAL :: wGP(0:N_in)         ! Gausspoint weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER                   :: iGP,iter,nIter
REAL                      :: Tol              !tolerance for Newton iteration
REAL                      :: q,qder,L         !q=L_{N_in+1}-L_{N_in-1},qder is derivative, L=L_{N_in}
REAL                      :: dx               !Newton step
REAL                      :: pi,cont1,cont2   !temporary variable for evaluation of parter nodes positions
!===================================================================================================================================
xGP(0)=-1.
xGP(N_in)= 1.
IF(PRESENT(wGP))THEN
  wGP(0)= 2./REAL(N_in*(N_in+1))
  wGP(N_in)=wGP(0)
END IF
IF(N_in.GT.1)THEN
  Tol=1.E-15
  nIter=10 
  pi=4.*atan(1.)
  cont1=pi/REAL(N_in) ! pi/N_in
  cont2=3./(REAL(8*N_in)*pi) ! 3/(8*N_in*pi)
  DO iGP=1,(N_in+1)/2-1 !since points are symmetric, only left side is computed
    xGP(iGP)=-cos(cont1*(REAL(iGP)+0.25)-cont2/(REAL(iGP)+0.25)) !initial guess
    ! Newton iteration
    DO iter=0,nIter
      CALL qAndLEvaluation(N_in,xGP(iGP),q,qder,L)
      dx=-q/qder
      xGP(iGP)=xGP(iGP)+dx
      IF(abs(dx).LT.Tol*abs(xGP(iGP))) EXIT
    END DO ! iter
    IF(iter.GT.nIter) THEN
      SWRITE(*,*) 'maximum iteration steps >10 in Newton iteration for LGL point:'
      xGP(iGP)=-cos(cont1*(REAL(iGP)+0.25)-cont2/(REAL(iGP)+0.25)) !initial guess
      ! Newton iteration
      DO iter=0,nIter
        SWRITE(*,*)'iter,x^i',iter,xGP(iGP)     !DEBUG 
        CALL qAndLEvaluation(N_in,xGP(iGP),q,qder,L)
        dx=-q/qder
        xGP(iGP)=xGP(iGP)+dx
        IF(abs(dx).LT.Tol*abs(xGP(iGP))) EXIT
      END DO ! iter
      CALL abort(__STAMP__,&
                 'Code stopped!',999,999.)
    END IF ! (iter.GT.nIter)
    CALL qAndLEvaluation(N_in,xGP(iGP),q,qder,L)
    xGP(N_in-iGP)=-xGP(iGP)
    IF(PRESENT(wGP))THEN
      wGP(iGP)=wGP(0)/(L*L)
      wGP(N_in-iGP)=wGP(iGP)
    END IF
  END DO ! iGP
END IF !(N_in.GT.1)
IF(mod(N_in,2) .EQ. 0) THEN
  xGP(N_in/2)=0.
  CALL qAndLEvaluation(N_in,xGP(N_in/2),q,qder,L)
  IF(PRESENT(wGP))wGP(N_in/2)=wGP(0)/(L*L)
END IF ! (mod(N_in,2) .EQ. 0)
END SUBROUTINE LegGaussLobNodesAndWeights



SUBROUTINE BarycentricWeights(N_in,xGP,wBary)
!===================================================================================================================================
! algorithm 30, Kopriva
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in               ! polynomial degree 
REAL,INTENT(IN)    :: xGP(0:N_in)        ! Gausspoint positions for the reference interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: wBary(0:N_in)      ! barycentric weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: iGP,jGP
!===================================================================================================================================
wBary(:)=1.
DO iGP=1,N_in
  DO jGP=0,iGP-1
    wBary(jGP)=wBary(jGP)*(xGP(jGP)-xGP(iGP))
    wBary(iGP)=wBary(iGP)*(xGP(iGP)-xGP(jGP))
  END DO ! jGP
END DO ! iGP
wBary(:)=1./wBary(:)
END SUBROUTINE BarycentricWeights



SUBROUTINE PolynomialDerivativeMatrix(N_in,xGP,D)
!===================================================================================================================================
! algorithm 37, Kopriva
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in              ! polynomial degree
REAL,INTENT(IN)    :: xGP(0:N_in)       ! Gausspoint positions for the reference interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: D(0:N_in,0:N_in)     ! differentiation Matrix
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: iGP,iLagrange
REAL               :: wBary(0:N_in) 
!===================================================================================================================================
CALL BarycentricWeights(N_in,xGP,wBary)
D(:,:)=0.
DO iLagrange=0,N_in
  DO iGP=0,N_in
    IF(iLagrange.NE.iGP)THEN
      D(iGP,iLagrange)=wBary(iLagrange)/(wBary(iGP)*(xGP(iGP)-xGP(iLagrange)))
      D(iGP,iGP)=D(iGP,iGP)-D(iGP,iLagrange)
    END IF ! (iLagrange.NE.iGP)
  END DO ! iGP
END DO ! iLagrange
END SUBROUTINE PolynomialDerivativeMatrix



FUNCTION ALMOSTEQUAL(x,y)
!===================================================================================================================================
! Based on Algorithm 139, Kopriva
! Compares two real numbers
! Depends on PP_RealTolerance
! Takes into account that x,y is located in-between [-1;1]
!===================================================================================================================================
USE MODH_PreProc
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
REAL,INTENT(IN) :: x,y         ! 2 scalar real numbers
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
LOGICAL         :: AlmostEqual ! TRUE if |x-y| < 2*PP_RealTolerance
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
!===================================================================================================================================
AlmostEqual=.FALSE.
IF((x.EQ.0.).OR.(y.EQ.0.)) THEN
  IF(ABS(x-y).LE.2.*PP_RealTolerance) AlmostEqual=.TRUE.
ELSE ! x, y not zero
  IF((ABS(x-y).LE.PP_RealTolerance*ABS(x)).AND.((ABS(x-y).LE.PP_RealTolerance*ABS(y)))) AlmostEqual=.TRUE.
END IF ! x,y zero
END FUNCTION ALMOSTEQUAL



SUBROUTINE LagrangeInterpolationPolys(x,N_in,xGP,wBary,L)
!============================================================================================================================
! Algorithm 34, Kopriva
! Computes all Lagrange functions evaluated at position x in [-1;1]
! Uses function ALMOSTEQUAL
!============================================================================================================================
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------
!input parameters
REAL, INTENT(IN)   :: x          ! Coordinate
INTEGER,INTENT(IN) :: N_in          ! polynomial degree
REAL,INTENT(IN)    :: xGP(0:N_in)   ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(IN)    :: wBary(0:N_in) ! Barycentric weights
!----------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: L(0:N_in)     ! Lagrange basis functions evaluated at x
!----------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER                   :: iGP
LOGICAL                   :: xEqualGP ! is x equal to a Gauss Point
REAL                      :: DummySum
!============================================================================================================================
xEqualGP=.FALSE.
DO iGP=0,N_in
  L(iGP)=0.
  IF(ALMOSTEQUAL(x,xGP(iGP))) THEN
    L(iGP)=1.
    xEqualGP=.TRUE.
  END IF ! (ALMOSTEQUAL(x,xGP(iGP)))
END DO ! iGP
! if x is equal to a Gauss point, L=(0,....,1,....0)
IF(xEqualGP) RETURN
DummySum=0.
DO iGP=0, N_in
  L(iGP)=wBary(iGP)/(x-xGP(iGP))
  DummySum=DummySum+L(iGP)
END DO

DO iGP=0,N_in
  L(iGP)=L(iGP)/DummySum
END DO
END SUBROUTINE LagrangeInterpolationPolys


SUBROUTINE GetNodesAndWeights(N_in,NodeType_in,xIP,wIP,wIPBary)
!===================================================================================================================================
! Compute 1D nodes and weights and build the Vandermonde-Matrix
!===================================================================================================================================
! MODULES
USE MODH_Globals
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN)                 :: N_in         ! Number of 1D points
CHARACTER(LEN=*),INTENT(IN)        :: NodeType_in  ! Type of 1D points
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)                   :: xIP(0:N_in)
REAL,INTENT(OUT),OPTIONAL          :: wIP(0:N_in)
REAL,INTENT(OUT),OPTIONAL          :: wIPBary(0:N_in)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                            :: i
!===================================================================================================================================
IF(PRESENT(wIP))THEN
  SELECT CASE(TRIM(NodeType_in))
  CASE('GAUSS')
    CALL LegendreGaussNodesAndWeights(N_in,xIP,wIP)
  CASE('GAUSS-LOBATTO')
    CALL LegGaussLobNodesAndWeights(N_in,xIP,wIP)
  CASE('CHEBYSHEV-GAUSS-LOBATTO')
    CALL ChebyGaussLobNodesAndWeights(N_in,xIP,wIP)
  CASE('VISU')
    DO i=0,N_in
      xIP(i) = 2.*REAL(i)/REAL(N_in) - 1.  
    END DO
    ! Trapez rule for integration !!!
    wIP(:) = 2./REAL(N_in)
    wIP(0) = 0.5*wIP(0)
    wIP(N_in) = 0.5*wIP(N_in)
  CASE('VISU_INNER')
    DO i=0,N_in
      xIP(i) = 1./REAL(N_in+1)+2.*REAL(i)/REAL(N_in+1) - 1.  
    END DO
    ! first order intergration !!!
    wIP=2./REAL(N_in+1)
  CASE DEFAULT
    CALL Abort(__STAMP__,&
      'NodeType "'//TRIM(NodeType_in)//'" in GetNodesAndWeights not found!')
  END SELECT
ELSE
  SELECT CASE(TRIM(NodeType_in))
  CASE('GAUSS')
    CALL LegendreGaussNodesAndWeights(N_in,xIP)
  CASE('GAUSS-LOBATTO')
    CALL LegGaussLobNodesAndWeights(N_in,xIP)
  CASE('CHEBYSHEV-GAUSS-LOBATTO')
    CALL ChebyGaussLobNodesAndWeights(N_in,xIP)
  CASE('VISU')
    DO i=0,N_in
      xIP(i) = 2.*REAL(i)/REAL(N_in) - 1.  
    END DO
  CASE('VISU_INNER')
    DO i=0,N_in
      xIP(i) = 1./REAL(N_in+1)+2.*REAL(i)/REAL(N_in+1) - 1.  
    END DO
  CASE DEFAULT
    CALL Abort(__STAMP__,&
      'NodeType "'//NodeType_in//'" in GetNodesAndWeights not found!')
  END SELECT
END IF !present wIP
IF(PRESENT(wIPBary)) CALL BarycentricWeights(N_in,xIP,wIPBary)
END SUBROUTINE GetNodesAndWeights


SUBROUTINE GetVandermonde(N_in,NodeType_in,N_out,NodeType_out,Vdm_In_Out,Vdm_Out_In,modal)
!===================================================================================================================================
! Compute 1D nodes and weights and build the Vandermonde-Matrix
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN)                 :: N_in,N_out                 ! Number of 1D input points / output points
CHARACTER(LEN=255),INTENT(IN)      :: NodeType_in,NodeType_out   ! Type of 1D input points / output points
LOGICAL,INTENT(IN),OPTIONAL        :: modal                      ! 
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)                   :: Vdm_In_out(0:N_out,0:N_in)
REAL,INTENT(OUT),OPTIONAL          :: Vdm_Out_In(0:N_in,0:N_out)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                            :: i
REAL                               :: xIP_in(0:N_in)
REAL                               :: xIP_out(0:N_out)
REAL                               :: wBary_in(0:N_in)
REAL                               ::  Vdm_Leg_in( 0:N_in,0:N_in)
REAL                               :: sVdm_Leg_in( 0:N_in,0:N_in)
REAL                               ::  Vdm_Leg_out(0:N_out,0:N_out)
REAL                               :: sVdm_Leg_out(0:N_out,0:N_out)
LOGICAL                            :: modalLoc
!===================================================================================================================================
modalLoc=.FALSE.
IF(PRESENT(modal)) modalLoc=modal

! Check if change Basis is needed
IF((TRIM(NodeType_out).EQ.TRIM(NodeType_in)).AND.(N_in.EQ.N_out))THEN
  Vdm_In_Out=0.
  DO i=0,N_in
    Vdm_In_out(i,i)=1.
  END DO
  IF(PRESENT(Vdm_Out_In))THEN
    Vdm_Out_In=0.
    DO i=0,N_Out
      Vdm_Out_In(i,i)=1.
    END DO
  END IF
ELSE
  ! Input points
  CALL GetNodesAndWeights(N_in,NodeType_in,xIP_in)
  CALL BarycentricWeights(N_in,xIP_in,wBary_in)
  ! Output points
  CALL GetNodesAndWeights(N_out,NodeType_out,xIP_out)

  IF(modalLoc)THEN
    CALL buildLegendreVdm(N_In, xIP_in, Vdm_Leg_in, sVdm_Leg_in)
    CALL buildLegendreVdm(N_Out,xIP_out,Vdm_Leg_out,sVdm_Leg_out)
  END IF

  IF((N_Out.LT.N_In).AND.modalLoc)THEN
    Vdm_In_Out=MATMUL(Vdm_Leg_Out(0:N_Out,0:N_Out),sVdm_Leg_In(0:N_Out,0:N_In))
  ELSE
    CALL InitializeVandermonde(N_in,N_out,wBary_in,xIP_in,xIP_out,Vdm_In_Out)
  END IF
  IF(PRESENT(Vdm_Out_In))THEN
    IF((N_In.LT.N_Out).AND.modalLoc)THEN
      Vdm_Out_In=MATMUL(Vdm_Leg_In(0:N_In,0:N_In),sVdm_Leg_Out(0:N_In,0:N_Out))
    ELSE
      CALL BarycentricWeights(N_out,xIP_out,wBary_in)
      CALL InitializeVandermonde(N_out,N_in,wBary_in,xIP_out,xIP_in,Vdm_Out_In)
    END IF
  END IF
END IF
END SUBROUTINE GetVandermonde

END MODULE MODH_Basis

