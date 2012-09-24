"""Solves the PDE problems on the surface of a brain.
Also outputs PETSc matrices.
"""
import numpy as np
import pickle


from cp.surfaces import Mesh
from cp.tools.io import load_ply
from cp.build_matrices import build_interp_matrix, build_diff_matrix
# TODO: move coordinate_transform out of cp.surfaces (maybe to
# cp.tools?)
#from cp.surfaces.coordinate_transform import cart2sph

PLOT = False

if PLOT:
    try:
        from mayavi import mlab
    except ImportError:
        from enthought.mayavi import mlab


# Load vertices and faces, and instantiate surface
v, f = load_ply('brain-lh_scale_1.ply')
m = Mesh(v, f)

p = 3
diff_stencil_arm = 1
dim = 3

index, distance, grid, dx = m.grid(num_blocks_per_dim=41,
                                   levels=2,
                                   p=p,
                                   diff_stencil_arm=diff_stencil_arm)
cp, dist, _, _ = m.closest_point(grid, index)

# The points in `grid` can be thought to be a subset of a virtual grid
# (for instance, the result of meshgrid). `ll` is the lower left
# corner of such virtual grid, and `ur` the upper right corner. The
# padding (\pm 3 * dx) should not be needed, but I haven't check if
# that's true. Fixing the shape of this virtual grid let's us easily
# go from an (i,j,...) index to a linear index and back.
ll = np.array(dim * [grid.min()]) - 3 * dx
ur = np.array(dim * [grid.max()]) + 3 * dx
virtual_grid_shape = np.abs(ur-ll) / dx + 1

# The (i,j,...) indices of the grid points, taking `ll` as origin.
int_grid = np.round((grid - ll) / dx).astype(np.int)

# To set the initial conditions I directly set a value for each grid
# point. Another option would be to set the values in the vertices,
# then interpolate to get the values in each closest point (using
# scipy.interpolate.griddata) and finally extend that to the whole
# grid
#th, phi, r = cart2sph(grid[:, 0], grid[:, 1], grid[:, 2])
#u = np.cos(phi + np.pi / 2)
u = grid[:,0]**3
# Let's keep a copy of the initial conditions
initial_u = u.copy()

# Let's build the matrices. TODO: I think it would be nicer to use
# `grid` instead of `int_grid`. It is a simple change.
E = build_interp_matrix(int_grid, cp, dx, p, ll, virtual_grid_shape)
# TODO: being able to select different laplacian operators. Currently
# it uses the second order laplacian for 2D and 3D. We could probably
# use stencils.py, and give the stencil as a parameter
L = build_diff_matrix(int_grid, dx, virtual_grid_shape)

# Points in the surface of the sphere, used por plotting
#xp, yp, zp = Sphere().parametric_grid(65)
#_, phi_plot, _ = cart2sph(xp, yp, zp)
Eplot = build_interp_matrix(int_grid,
                            m.vertices,
                            dx, 1, ll, virtual_grid_shape)

if PLOT:
    # Plotting code. Build a pipeline to be able to change the data later.
    #src = mlab.pipeline.grid_source(xp, yp, zp,
    #                                scalars=(Eplot * u).reshape(xp.shape))
    src = mlab.pipeline.triangular_mesh_source(m.vertices[:,0],
                                               m.vertices[:,1],
                                               m.vertices[:,2], m.faces,
                                               scalars=(Eplot * u))
    normals = mlab.pipeline.poly_data_normals(src)
    surf = mlab.pipeline.surface(normals)
    mlab.colorbar()

# reaction-diffusion equation
# parameters:
alpha = 0.1     # coefficient of reaction term
gammaS = 1      # coefficient of sources term
v0 = 1          # magnitude of point sources

# load source locations
#(sources) = pickle.load(file('brain_sources.pickle'))
nsrcs = 3   # TODO: make this the size of the sources matrix!
# build the source term
v = 0
varsq = dx      # scale delta fns somehow
#for srccount in xrange(nsrcs)
  #vdist = (xg-sources(srccount,1)).^2 + (yg-cpyg(si)).^2 + (zg-cpzg(si)).^2
  #v = v + exp( -vdist/(2*varsq))
# cp-ext
#v = E*v


# choose a Closest Point Method algorithm
cpm = 0

# choose timestep
if cpm == 0:
    dt = 0.2 * np.min(dx)**2
elif cpm == 1:
    dt = 0.2 * np.min(dx)**2
elif cpm == 2:
    dt = 0.5 * np.min(dx)

# build the vGMM matrix
if cpm == 1 or cpm == 2:
    #I = speye(L.shape[0], L.shape[1])
    I = speye(*L.shape)
    lamb = 4.0/np.min(dx)**2
    M = E*L - lamb*(I - E)
if cpm == 2:
    A = I - dt*M


Tf = 0.2
dt = 0.2 * np.min(dx)**2
numtimesteps = int(Tf // dt + 1)
dt = Tf / numtimesteps
errors = []  # To store the error at each timestep
# Explicit Forward Euler time stepping
for kt in xrange(numtimesteps):
    if cpm == 0:
        # explicit Euler, Ruuth--Merriman style
        unew = u + dt * (L*u)
        u = E*unew
    elif cpm == 1:
        # explicit Euler, von Glehn--Maerz--Macdonald
        unew = u + dt * (M*u)
        u = unew;
    elif cpm == 2:
        # implicit Euler, vGMM
        unew = splinalg.spsolve(A, u)
        u = unew;
    # unew = u + dt * (L*u)
    # u = E*unew
    t = kt * dt
    if not kt%100 or kt == (numtimesteps-1):
        print "time: {0:2f}, {1:2f} %".format(t, 100 * float(kt) / numtimesteps)
        uplot = Eplot * u
        #true_solution = np.exp(-2*t) * np.cos(phi_plot + np.pi / 2)
        #step_error = (np.abs(true_solution - sphplot.reshape(xp.shape)).sum() /
        #np.abs(true_solution).sum())
        #errors.append(step_error)
        if PLOT:
            src.data.point_data.scalars = uplot
            src.data.point_data.scalars.name = 'scalars'
            src.data.modified()

cpm = 0
print 'saving matrices to petsc format on disk'
import cp.tools.scipy_petsc_conversions as conv
if cpm == 0:
    conv.save_scipy_to_petsc_ondisk(L, 'Lmatrix.dat')
    conv.save_scipy_to_petsc_ondisk(E, 'Ematrix.dat')
elif cpm == 1:
    conv.save_scipy_to_petsc_ondisk(M, 'Mmatrix.dat')
elif cpm == 2:
    conv.save_scipy_to_petsc_ondisk(A, 'Amatrix.dat')

final_u = u
print 'saving dx, ICs, soln to disk'
pickle.dump((dx, cpm, Tf, numtimesteps, dt, initial_u, final_u), file('non_petsc_data.pickle','w'))


initial_u_plot = (Eplot * initial_u).astype('f');
pickle.dump((dx, Tf, numtimesteps, dt, initial_u_plot), file('brain_IC_plotvec.pickle','w'))
pickle.dump((dx, Tf, numtimesteps, dt, uplot.astype('f')), file('brain_final_plotvec.pickle','w'))
