% File: expe07_PDE_fast_SLS.m
% Author: Antoine Leeman (aleeman(at)ethz(dot)ch)
% License: MIT
% -----------------------------------------------------------------------------

%%
m = LinearBoltzmann('0.2');

Q = eye(m.nx);
R = 0*eye(m.nu);
Qf = Q;
N = 5;

x0 = zeros(m.nx,1);
kkt = KKT_SLS(N,Q,R,m,Qf);


nx = m.nx;
nu = m.nu;
ni = m.ni;

S = cell(N,N);
K = cell(N,N);

C_f = m.Cf;
C = m.C;

A = m.A;
B = m.B;
tic
%Riccati recursion
for jj=1:N-1
    S{N,jj} = kkt.Q_reg_f;
    for kk=N-1:-1:jj
        Cxk = kkt.Q_reg;
        Cuk = kkt.R_reg;
        [K{kk,jj}, S{kk,jj}] = kkt.riccati_step(A,B,Cxk,Cuk,S{kk+1,jj});
    end
end

%forward propagation
Phi_x_kj = cell(N,N);
Phi_u_kj = cell(N,N);

for jj=1:N % iteration on the disturbance number
    Phi_x_kj{jj,jj} = m.E; % todo: make this time-varying (especially for nonlinear case)
    for kk=jj:N-1
        Phi_u_kj{kk,jj} = K{kk,jj}*Phi_x_kj{kk,jj};
        A_cl = A + B*K{kk,jj};
        Phi_x_kj{kk+1,jj} = A_cl*Phi_x_kj{kk,jj};
    end
end
time = toc
for i = 1:numel(Phi_x_kj)
    if isempty(Phi_x_kj{i})
        Phi_x_kj{i} = zeros(nx);
    end
end

for i = 1:numel(Phi_u_kj)
    if isempty(Phi_u_kj{i})
        Phi_u_kj{i} = zeros(nu,nx);
    end
end


Phi_x = cell2mat(Phi_x_kj);
Phi_u = cell2mat(Phi_u_kj);


save('../data/dx0_2.mat', 'Phi_x', 'Phi_u', 'm', 'kkt', 'time');
%clear all;
%%

m = LinearBoltzmann('0.5');

Q = eye(m.nx);
R = 0*eye(m.nu);
Qf = Q;
N = 5;

x0 = zeros(m.nx,1);
kkt = KKT_SLS(N,Q,R,m,Qf);


nx = m.nx;
nu = m.nu;
ni = m.ni;

S = cell(N,N);
K = cell(N,N);

C_f = m.Cf;
C = m.C;

A = m.A;
B = m.B;
tic
%Riccati recursion
for jj=1:N-1
    S{N,jj} = kkt.Q_reg_f;
    for kk=N-1:-1:jj
        Cxk = kkt.Q_reg;
        Cuk = kkt.R_reg;
        [K{kk,jj}, S{kk,jj}] = kkt.riccati_step(A,B,Cxk,Cuk,S{kk+1,jj});
    end
end

%forward propagation
Phi_x_kj = cell(N,N);
Phi_u_kj = cell(N,N);

for jj=1:N % iteration on the disturbance number
    Phi_x_kj{jj,jj} = m.E; % todo: make this time-varying (especially for nonlinear case)
    for kk=jj:N-1
        Phi_u_kj{kk,jj} = K{kk,jj}*Phi_x_kj{kk,jj};
        A_cl = A + B*K{kk,jj};
        Phi_x_kj{kk+1,jj} = A_cl*Phi_x_kj{kk,jj};
    end
end
time = toc

for i = 1:numel(Phi_x_kj)
    if isempty(Phi_x_kj{i})
        Phi_x_kj{i} = zeros(nx);
    end
end

for i = 1:numel(Phi_u_kj)
    if isempty(Phi_u_kj{i})
        Phi_u_kj{i} = zeros(nu,nx);
    end
end


Phi_x = cell2mat(Phi_x_kj);
Phi_u = cell2mat(Phi_u_kj);


save('../data/dx0_5.mat', 'Phi_x', 'Phi_u', 'm', 'kkt', 'time');
clear all;

%%


m = LinearBoltzmann('0.25');

Q = eye(m.nx);
R = 0*eye(m.nu);
Qf = Q;
N = 5;

x0 = zeros(m.nx,1);
kkt = KKT_SLS(N,Q,R,m,Qf);


nx = m.nx;
nu = m.nu;
ni = m.ni;

S = cell(N,N);
K = cell(N,N);

C_f = m.Cf;
C = m.C;

A = m.A;
B = m.B;
tic
%Riccati recursion
for jj=1:N-1
    S{N,jj} = kkt.Q_reg_f;
    for kk=N-1:-1:jj
        Cxk = kkt.Q_reg;
        Cuk = kkt.R_reg;
        [K{kk,jj}, S{kk,jj}] = kkt.riccati_step(A,B,Cxk,Cuk,S{kk+1,jj});
    end
end

%forward propagation
Phi_x_kj = cell(N,N);
Phi_u_kj = cell(N,N);

for jj=1:N % iteration on the disturbance number
    Phi_x_kj{jj,jj} = m.E; % todo: make this time-varying (especially for nonlinear case)
    for kk=jj:N-1
        Phi_u_kj{kk,jj} = K{kk,jj}*Phi_x_kj{kk,jj};
        A_cl = A + B*K{kk,jj};
        Phi_x_kj{kk+1,jj} = A_cl*Phi_x_kj{kk,jj};
    end
end
time = toc
for i = 1:numel(Phi_x_kj)
    if isempty(Phi_x_kj{i})
        Phi_x_kj{i} = zeros(nx);
    end
end

for i = 1:numel(Phi_u_kj)
    if isempty(Phi_u_kj{i})
        Phi_u_kj{i} = zeros(nu,nx);
    end
end


Phi_x = cell2mat(Phi_x_kj);
Phi_u = cell2mat(Phi_u_kj);


save('../data/dx0_25.mat', 'Phi_x', 'Phi_u', 'm', 'kkt', 'time');
clear all

%%
disp('This last example requires a large memory. Hence the data and solution is not stored online.')
m = LinearBoltzmann('0.1');

Q = eye(m.nx);
R = 0* eye(m.nu);
Qf = Q;
N = 5;

kkt = KKT_SLS(N,Q,R,m,Qf);


nx = m.nx;
nu = m.nu;
ni = m.ni;

S = cell(N,N);
K = cell(N,N);

A = m.A;
B = m.B;
tic
%Riccati recursion
for jj=1:N-1
    S{N,jj} = kkt.Q_reg_f;
    for kk=N-1:-1:jj
        Cxk = kkt.Q_reg;
        Cuk = kkt.R_reg;
        [K{kk,jj}, S{kk,jj}] = kkt.riccati_step(A,B,Cxk,Cuk,S{kk+1,jj});
    end
end

%forward propagation
Phi_x_kj = cell(N,N);
Phi_u_kj = cell(N,N);

for jj=1:N % iteration on the disturbance number
    Phi_x_kj{jj,jj} = m.E; % todo: make this time-varying (especially for nonlinear case)
    for kk=jj:N-1
        Phi_u_kj{kk,jj} = K{kk,jj}*Phi_x_kj{kk,jj};
        A_cl = A + B*K{kk,jj};
        Phi_x_kj{kk+1,jj} = A_cl*Phi_x_kj{kk,jj};
    end
end
time = toc

for i = 1:numel(Phi_x_kj)
    if isempty(Phi_x_kj{i})
        Phi_x_kj{i} = zeros(nx);
    end
end

for i = 1:numel(Phi_u_kj)
    if isempty(Phi_u_kj{i})
        Phi_u_kj{i} = zeros(nu,nx);
    end
end


Phi_x = cell2mat(Phi_x_kj);
Phi_u = cell2mat(Phi_u_kj);


save('../data/dx0_1.mat', 'Phi_x', 'Phi_u', 'm', 'kkt', 'time');
%clear all;