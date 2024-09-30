% File: LinearBoltzmann.m
% Author: Antoine Leeman (aleeman(at)ethz(dot)ch)
% License: MIT
% -----------------------------------------------------------------------------
%%
classdef LinearBoltzmann < LinearSystem
    properties

    end
    methods
        function obj = HeatConduction(dx)

            switch dx
                case '0.1'
                    A = load('A_dx0.1.mat').A;
                    B = load('B_dx0.1.mat').B;
                    obj.A = A;
                    obj.B = B;
                    disp('imported dx = 0.1')
                
                case '0.2'
                    A = load('A_dx0.2.mat').A;
                    B = load('B_dx0.2.mat').B;
                    obj.A = A;
                    obj.B = B;
                    disp('imported dx = 0.2')

                case '0.25'
                    A = load('A_dx0.25.mat').A;
                    B = load('B_dx0.25.mat').B;
                    obj.A = A;
                    obj.B = B;
                    disp('imported dx = 0.25')

                case '0.5'
                    A = load('A_dx0.5.mat').A;
                    B = load('B_dx0.5.mat').B;
                    obj.A = A;
                    obj.B = B;
                    disp('imported dx = 0.1')



                otherwise
                    disp('dx not supported')
            end
            obj.E = eye(size(A,1));

            obj.nx=size(obj.A,1);
            obj.nw = obj.nx;
            obj.nu=size(obj.B,2);


            obj.ni = 2*obj.nx+2*obj.nu;
            obj.ni_x =2*obj.nx+2*obj.nu;

        end

    end
end

