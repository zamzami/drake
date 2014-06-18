function [p,xtraj,utraj,z,F,info,traj_opt] = testTrajOpt(xtraj,utraj)
p = PlanarRigidBodyManipulator('Acrobot.urdf');
% p = AcrobotPlant();

N = 30;
T = 5;
T0 = 2;

initial_cost = [];
% final_cost = NonlinearConstraint(-inf,inf,N+3,@final_cost_fun);
final_cost = [];
running_cost = NonlinearConstraint(-inf,inf,6,@running_cost_fun);



t_init = linspace(0,T0,N);

if nargin < 2
  traj_init.x = PPTrajectory(foh(t_init,zeros(4,N)));
  traj_init.u = PPTrajectory(foh(t_init,randn(1,N)));
else
  traj_init.x = xtraj;
  traj_init.u = utraj;
end
T_span = [T/2 T];

x0 = zeros(4,1);
xf = [pi;0;0;0];

traj_opt = DircolTrajectoryOptimization(p,N,T_span,struct());
% traj_opt = MidpointTrajectoryOptimization(p,N,T_span,struct());
% traj_opt = FEDirtranTrajectoryOptimization(p,N,T_span,struct());
% traj_opt = BEDirtranTrajectoryOptimization(p,N,T_span,struct());
% traj_opt = traj_opt.setCheckGrad(true);
snprint('snopt.out');
traj_opt = traj_opt.setSolverOptions('snopt','MajorIterationsLimit',200);
traj_opt = traj_opt.addRunningCost(running_cost);
traj_opt = traj_opt.addBoundingBoxStateConstraint(BoundingBoxConstraint(x0,x0),1);
% traj_opt = traj_opt.addBoundingBoxStateConstraint(BoundingBoxConstraint(xf,xf),N);
traj_opt = traj_opt.addLinearStateConstraint(LinearConstraint(xf,xf,eye(4)),N);
[xtraj,utraj,z,F,info] = traj_opt.solveTraj(t_init,traj_init);

% keyboard
end

function [f,df] = running_cost_fun(h,x,u)
  f = h*u^2;
  df = [u^2 zeros(1,4) 2*u*h];
end

function [f,df] = final_cost_fun(h,x)
  K = 10;
  f = K*sum(h);
  df = [K*ones(1,length(h)) zeros(1,4)];
end