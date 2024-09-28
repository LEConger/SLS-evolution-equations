import numpy as np
from scipy.integrate import dblquad
from tqdm import tqdm
import multiprocessing as mp


# parameters
xmin     = -2
xmax     = 2
ymin     = -2
ymax     = 2
r        = 0.5
k        = 12
lambda_x = 2*(xmax - xmin)
lambda_y = 2*(ymax - ymin)
p        = 2
n_u      = 16 # must be perfect square
sqrt_n_u = int(np.sqrt(n_u))
u_loc_x  = np.linspace(xmin, xmax, sqrt_n_u + 1)[0:-1] + (xmax - xmin)/(2*sqrt_n_u) 
u_loc_y  = np.linspace(ymin, ymax, sqrt_n_u + 1)[0:-1] + (ymax - ymin)/(2*sqrt_n_u)
u_loc    = np.array([[x, y] for x in u_loc_x for y in u_loc_y])

def a(x, radius=r,p=p):
    mag_x = np.linalg.norm(x,p)
    if mag_x < radius:
        return 0.5*np.cos(np.pi*mag_x/radius) + 0.5
    else:
        return 0

def b(z,loc,radius=r):
    return -a(z-loc,radius=radius)

# trig functions for b
def sin_sin_integrand(x1, x2, i, j):
    return np.sin(np.pi * 2*i * x1 / lambda_x) * np.sin(np.pi * 2*j * x2 / lambda_y)
def cos_sin_integrand(x1, x2, i, j):
    return np.cos(np.pi * 2*i * x1 / lambda_x) * np.sin(np.pi * 2*j * x2 / lambda_y)
def sin_cos_integrand(x1, x2 , i, j):
    return np.sin(np.pi * 2*i * x1 / lambda_x) * np.cos(np.pi * 2*j * x2 / lambda_y)
def cos_cos_integrand(x1, x2, i, j):
    return np.cos(np.pi * 2*i * x1 / lambda_x) * np.cos(np.pi * 2*j * x2 / lambda_y)



def compute_coeffs(kk, jj, controller, u_loc, r, xmin, xmax, ymin, ymax,lambda_x,lambda_y):
    coeffs = np.zeros(4)
    if kk == 0 and jj == 0:
        kappa = 1
    elif kk == 0 or jj == 0:
        kappa = 2
    else:
        kappa = 4
    coeffs[0] = dblquad(lambda x1, x2: sin_sin_integrand(x1, x2, kk, jj) * b(np.array([x1, x2]), u_loc[controller], radius=r), xmin, xmax, ymin, ymax)[0] * kappa / (lambda_x * lambda_y)
    coeffs[1] = dblquad(lambda x1, x2: cos_sin_integrand(x1, x2, kk, jj) * b(np.array([x1, x2]), u_loc[controller], radius=r), xmin, xmax, ymin, ymax)[0] * kappa / (lambda_x * lambda_y)
    coeffs[2] = dblquad(lambda x1, x2: sin_cos_integrand(x1, x2, kk, jj) * b(np.array([x1, x2]), u_loc[controller], radius=r), xmin, xmax, ymin, ymax)[0] * kappa / (lambda_x * lambda_y)
    coeffs[3] = dblquad(lambda x1, x2: cos_cos_integrand(x1, x2, kk, jj) * b(np.array([x1, x2]), u_loc[controller], radius=r), xmin, xmax, ymin, ymax)[0] * kappa / (lambda_x * lambda_y)
    return (kk, jj, controller, coeffs)

def main():
    coeffs_b = np.zeros((k, k, 4, n_u))
    tasks = [(kk, jj, controller, u_loc, r, xmin, xmax, ymin, ymax, lambda_x, lambda_y) for kk in range(k) for jj in range(k) for controller in range(n_u)]
    
    with mp.Pool() as pool:
        results = list(tqdm(pool.starmap(compute_coeffs, tasks), total=len(tasks)))
    
    for kk, jj, controller, coeffs in results:
        coeffs_b[kk, jj, :, controller] = coeffs

    return coeffs_b

if __name__ == "__main__":
    coeffs_b = main()
    # save to numpy file
    k = 12
    np.save("coeffs_b_k{}_r05.npy".format(k), coeffs_b)