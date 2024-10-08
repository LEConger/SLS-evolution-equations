% File: KKT_SLS.m
% Author: Antoine Leeman (aleeman(at)ethz(dot)ch)
% Date: 06th March 2024
% License: MIT
% Reference:
%{
@article{leeman2024fast,
  title={Fast System Level Synthesis: Robust Model Predictive Control using Riccati Recursions},
  author={Leeman, Antoine P and K{\"o}hler, Johannes and Messerer, Florian and Lahr, Amon and Diehl, Moritz and Zeilinger, Melanie N},
  journal={arXiv preprint arXiv:2401.13762},
  year={2024}}
%}
% Link: https://arxiv.org/abs/2401.13762
% -----------------------------------------------------------------------------
%%
classdef KKT_SLS < OCP
    %All the KKT related functions for the SLS problem
    properties
        current_adj_corr;
        solver_forward;
        current_nominal;

        dh_dyk;
        dh_dxN;
        H_mat;
        H_mat_sparsity;
        lbg;
        ubg_current;
        nominal_ubg;
        lbx_fun;
        ubx_fun;
        A_current;

        beta_kj;
        bo_j;
        epsilon;
        eta_kj;
        mu_current;
        K_current;
        MAX_ITER;
    end

    methods
        function obj = KKT_SLS(N,Q,R,m,Qf)
            obj@OCP(N,Q,R,m,Qf);
            obj.epsilon = 1e-10;

            obj = obj.initialize_solver_forward('osqp');
            obj.nominal_ubg = [kron(ones(obj.N-1,1), [zeros(m.nx,1); m.d])]; % assume time invariant constraints + move to initialization

            % todo: add terminal constraint
            obj.nominal_ubg = [obj.nominal_ubg; zeros(m.nx,1); m.df];
            obj.ubg_current = obj.nominal_ubg;
            obj.MAX_ITER = 30;
            obj.eta_kj = cell(N-1,N-1);

        end

        function [solution, it_data] = solve(obj,x0)

            m = obj.m;
            N = obj.N;
            ni = m.ni;

            MAX_ITER = obj.MAX_ITER;
            current_x = zeros(m.nx,N+1);
            current_u = zeros(m.nu,N);
            it_data = struct();
            solution = struct();

            solution.feasible = false;
            obj.ubg_current = obj.nominal_ubg;
            obj.beta_kj = obj.epsilon.*ones(N-1,N-1,ni);
            solution.timeRiccatiControllerUpdate = 0;
            solution.timeTotalWithoutRiccatiControllerUpdate = 0;

            solution.V0 = nan(m.nu,1);
            for ii=1:MAX_ITER
                try
                    tic
                    [obj, ~,x_bar, u_bar, ~, ~] = obj.forward_solve(x0);
                    t = toc;
                    solution.timeTotalWithoutRiccatiControllerUpdate = solution.timeTotalWithoutRiccatiControllerUpdate+t;
                catch e
                    if contains(e.message, 'error_on_fail')
                        disp('infeasible forward solve');
                        return;
                    else
                        rethrow(e);
                    end
                end
                
                it_data(ii).x = x_bar;
                it_data(ii).u = u_bar;
                it_data(ii).bo_j = obj.bo_j;

                it_data(ii).delta = full(norm([current_x- x_bar; [current_u- u_bar, zeros(m.nu,1)]],'inf'));
                if it_data(ii).delta <= obj.CONV_EPS
                    disp('converged to an optimal solution');
                    solution.feasible =true;
                    solution.V0 = full(current_u(:,1));
                    solution.n_iter = ii;
                    return;
                else
                    current_x = x_bar;
                    current_u = u_bar;
                end
                tic
                obj = obj.update_cost_tube();
                t = toc;
                solution.timeTotalWithoutRiccatiControllerUpdate = solution.timeTotalWithoutRiccatiControllerUpdate+t;

                [obj, ~, t1] = obj.backward_solve();
                solution.timeRiccatiControllerUpdate = solution.timeRiccatiControllerUpdate+t1;
                tic;
                [obj,~, Phi_x, Phi_u] = obj.update_backoff();
                t = toc;
                it_data(ii).Phi_x = Phi_x;
                it_data(ii).Phi_u = Phi_u;
                solution.timeTotalWithoutRiccatiControllerUpdate = solution.timeTotalWithoutRiccatiControllerUpdate+t;
            end
            disp('no feasible solution found');

        end


        function obj = initialize_solver_forward(obj,solver)
            import casadi.*
            m=obj.m;

            R = obj.R;
            Q = obj.Q;
            Qf = obj.Qf;

            nx = m.nx;
            nu = m.nu;
            ni = m.ni;
            ni_x = m.ni_x;
            N = obj.N;
            A = m.A;
            B = m.B;
            C = m.C;
            Cf = m.Cf;

            obj.current_nominal = zeros(N*(nx+nu)+nx,1);
            A_mat = zeros(0,nx);
            I = eye(nx);
            Zero = zeros(ni,m.nx);
            Zerof = zeros(ni_x,m.nx);

            for kk=1:obj.N-1 % todo: no constraint on last time step x_N: could add a equality or box constraint
                S_fun =[A, B, -I ;...
                C, Zero];
                columnPadding = casadi.DM.zeros((kk-1)*(m.nx+m.ni), m.nu + m.nx);
                rowPadding = casadi.DM.zeros(m.nx+m.ni, (kk-1)*(m.nx+m.nu));

                A_mat = sparsify(vertcat(horzcat(A_mat, columnPadding), ...
                    horzcat(rowPadding, S_fun)));
                % todo: add affine part in the dynamics (e.g., linearized dynamics is affine): we could use a lifting
            end
            S_fun =[[A, B, -I ];...
                [Cf*A, Cf*B, Zerof]];
            columnPadding = casadi.DM.zeros((N-1)*(nx+ni), nu + nx);
            rowPadding = casadi.DM.zeros(nx+ni_x, (N-1)*(nx+nu));

            A_mat = sparsify(vertcat(horzcat(A_mat, columnPadding), ...
                horzcat(rowPadding, S_fun)));
            obj.A_current = A_mat;

            S_cost = blkdiag(Q, R);
            obj.H_mat = blkdiag(kron(eye(obj.N), S_cost),Qf);
            obj.H_mat = DM(sparse(obj.H_mat));

            obj.H_mat_sparsity = obj.H_mat.sparsity();
            options = struct;
            obj.solver_forward = conic('solver', solver, struct('a',A_mat.sparsity(), 'h',obj.H_mat_sparsity),options);
            obj.lbg = [kron(ones(obj.N-1,1), [zeros(m.nx,1);  -casadi.DM.inf(ni,1)])];
            obj.lbg = [obj.lbg; [zeros(m.nx,1);  -casadi.DM.inf(ni_x,1)] ];

            x0 = casadi.SX.sym('x0',nx);
            ubx = [x0+obj.epsilon; casadi.DM.inf(N*(nx+nu),1)];
            lbx = [x0-obj.epsilon; -casadi.DM.inf(N*(nx+nu),1)];

            obj.ubx_fun= casadi.Function('ubx_fun',{x0},{ubx});
            obj.lbx_fun= casadi.Function('lbx_fun',{x0},{lbx});

            % initialization of beta
            obj.beta_kj = obj.epsilon.*ones(N,N,ni);
        end

        function [obj, time, x_bar, u_bar, lambda_bar, mu_bar] = forward_solve(obj,x0)
            % import casadi.*
            m=obj.m;
            N = obj.N;
            nx = m.nx;
            nu = m.nu;
            ni = m.ni;

            sol = obj.solver_forward('a',obj.A_current,'h',obj.H_mat,'lba',obj.lbg,'uba',obj.ubg_current,'g',obj.current_adj_corr ,'lbx',obj.lbx_fun(x0),'ubx',obj.ubx_fun(x0));
            time = toc;
            obj.current_nominal = sol.x;

            y_sol = reshape([sol.x;zeros(nu,1)], [nx+nu, N+1]);
            x_bar = y_sol(1:nx,:);
            u_bar = y_sol(nx+1:end, 1:N);

            dual = reshape(sol.lam_a, [nx+ni,N]);
            mu_bar = dual(nx+1:end,:);
            lambda_bar = [sol.lam_x(1:nx), dual(1:nx,:)];

            obj.mu_current = full(mu_bar);
        end

        function [obj, K,time] = backward_solve(obj)

            m=obj.m;
            N = obj.N;
            nx = m.nx;
            nu = m.nu;
            ni = m.ni;

            S = cell(N,N);
            K = cell(N,N);

            C_f = m.Cf;
            C = m.C;

            A = m.A;
            B = m.B;
            tic;
            for jj=1:N-1
                eta_Nj = obj.eta_kj{N-1,jj}(1:1:m.ni_x);
                S{N,jj} = C_f' * diag(eta_Nj) *C_f+ obj.Q_reg_f;

                for kk=N-1:-1:jj
                    Ck = C'*diag(obj.eta_kj{kk,jj})*C;
                    Cxk = Ck(1:nx, 1:nx) + obj.Q_reg;
                    Cuk = Ck(nx+1:end, nx+1:end) + obj.R_reg;

                    % todo: Cxuk missing!

                   [K{kk,jj}, S{kk,jj}] = obj.riccati_step(A,B,Cxk,Cuk,S{kk+1,jj});
               end
            end
            time = toc;
            obj.K_current = K;
        end

        function [obj, bo_j, Phi_x_kj, Phi_u_kj] = update_backoff(obj)
            m=obj.m;
            N = obj.N;
            nx = m.nx;
            nu = m.nu;
            ni = m.ni;

            C = m.C;
            Phi_x_kj = cell(N,N);
            Phi_u_kj = cell(N,N); %todo: change size

            beta_kj = zeros(N-1,N-1,ni); % no tightening for the first time step
            A = m.A;
            B = m.B;
            for jj=1:N-1 % iteration on the disturbance number
                Phi_x_kj{jj,jj} = m.E; % todo: make this time-varying (especially for nonlinear case)
                for kk=jj:N-1
                    Phi_u_kj{kk,jj} = obj.K_current{kk,jj}*Phi_x_kj{kk,jj};
                    beta_kj(kk,jj,:) = vecnorm(C*full([Phi_x_kj{kk,jj};Phi_u_kj{kk,jj}]),2,2);
                    A_cl = A + B*obj.K_current{kk,jj};
                    Phi_x_kj{kk+1,jj} = A_cl*Phi_x_kj{kk,jj};
                end
            end

            bo_j = squeeze(sum(beta_kj,2))'; % remark: this operation scales with N^2 s!
            obj.beta_kj = beta_kj;
            obj.bo_j = bo_j;

            bo_0j = zeros(ni,1); %no tightening for the first time step
            update_ubg = reshape([zeros(nx,N); m.d - [bo_0j, bo_j]],[(N)*(ni+nx),1]);
            obj.ubg_current = update_ubg;

        end


        function obj = update_cost_tube(obj)
            N = obj.N;
            eta_kj = cell(N-1,N-1);

            for jj=1:N-1
                for kk=jj:N-1
                    eta_kj{kk,jj} = obj.mu_current(:,jj)./squeeze(sqrt(obj.beta_kj(kk,jj,:)));
                end
            end
            obj.eta_kj = eta_kj;
        end

        function [x,u] = convert_y_to_xu(obj,m,y)
            y_mat = reshape([y;zeros(m.nu,1)], [m.nx+m.nu, obj.N+1]);
            x = y_mat(1:m.nx,:);
            u = y_mat(m.nx+1:end, 1:obj.N);
        end

    end
end
