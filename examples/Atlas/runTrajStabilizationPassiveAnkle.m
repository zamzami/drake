function runTrajStabilizationPassiveAnkle(segment_number)

if ~checkDependency('gurobi')
  warning('Must have gurobi installed to run this example');
  return;
end
addpath(fullfile(getDrakePath,'examples','SpringFlamingo'));

if nargin < 1
  segment_number = -1; % do full traj
end

options.twoD = true;
options.view = 'right';
options.floating = true;
options.ignore_self_collisions = true;
options.terrain = RigidBodyFlatTerrain();
s = 'urdf/atlas_simple_spring_ankle.urdf';
dt = 0.001;
w = warning('off','Drake:RigidBodyManipulator:UnsupportedVelocityLimits');
r = TimeSteppingRigidBodyManipulator(s,dt,options);
warning(w);

nx = getNumStates(r);
nq = getNumPositions(r);
nu = getNumInputs(r);

v = r.constructVisualizer;
v.display_dt = 0.01;

data_dir = fullfile(getDrakePath,'examples','Atlas','data');
traj_file = strcat(data_dir,'/atlas_passiveankle_traj_lqr_082914.mat');
load(traj_file);
xtraj = xtraj.setOutputFrame(getStateFrame(r));
% v.playback(xtraj,struct('slider',true));

support_times = zeros(1,length(Straj_full));
for i=1:length(Straj_full)
  support_times(i) = Straj_full{i}.tspan(1);
end

options.right_foot_name = 'r_foot';
options.left_foot_name = 'l_foot'; 

lfoot_ind = findLinkInd(r,options.left_foot_name);
rfoot_ind = findLinkInd(r,options.right_foot_name);  

support_times(2) = support_times(2);
% manually specifiy modes for now
% supports = [RigidBodySupportState(r,lfoot_ind); ...
%   RigidBodySupportState(r,[lfoot_ind,rfoot_ind]); ...
%   RigidBodySupportState(r,rfoot_ind); ...
%   RigidBodySupportState(r,rfoot_ind)];
% supports = [RigidBodySupportState(r,lfoot_ind); ...
%   RigidBodySupportState(r,[lfoot_ind,rfoot_ind],{{'heel','toe'},{'heel'}}); ...
%   RigidBodySupportState(r,[lfoot_ind,rfoot_ind]); ...
%   RigidBodySupportState(r,[lfoot_ind,rfoot_ind],{{'toe'},{'toe','heel'}});...
%   RigidBodySupportState(r,rfoot_ind)];
supports = [RigidBodySupportState(r,lfoot_ind); ...
  RigidBodySupportState(r,[lfoot_ind,rfoot_ind],{{'heel','toe'},{'heel'}}); ...
  RigidBodySupportState(r,[lfoot_ind,rfoot_ind],{{'toe'},{'heel','toe'}}); ...
  RigidBodySupportState(r,rfoot_ind)];



if segment_number<1
  B=Btraj;
  S=Straj_full;
  t0 = xtraj.tspan(1);
  tf = xtraj.tspan(2);
else
  B=Btraj{segment_number};
  S=Straj_full{segment_number};
  t0 = Btraj{segment_number}.tspan(1);
  tf = Btraj{segment_number}.tspan(2); 
end

ctrl_data = FullStateQPControllerData(true,struct(...
  'B',{B},...
  'S',{S},...
  'R',R,... 
  'x0',xtraj,...
  'u0',utraj,...
  'support_times',support_times,...
  'supports',supports));

% instantiate QP controller
options.slack_limit = 0;
options.w_qdd = 0.0*ones(nq,1);
options.w_grf = 0.0;
options.w_slack = 0.0;
options.Kp_accel = 0.0;
options.contact_threshold = 0.001;
qp = FullStateQPController(r,ctrl_data,options);

% feedback QP controller with spring flamingo
ins(1).system = 1;
ins(1).input = 2;
outs(1).system = 2;
outs(1).output = 1;
sys = mimoFeedback(qp,r,[],[],ins,outs);

% feedback foot contact detector 
options.use_contact_logic_OR = false;
fc = FootContactBlock(r,ctrl_data,options);
sys = mimoFeedback(fc,sys,[],[],[],outs);
  
S=warning('off','Drake:DrakeSystem:UnsupportedSampleTime');
output_select(1).system=1;
output_select(1).output=1;
sys = mimoCascade(sys,v,[],[],output_select);
warning(S);

tspan = xtraj.tspan();
 x00 = xtraj.eval(t0);
x0 = [    0*0.2787
    0.9169
    0.5230
   -0.3310
    0.0975
   -0.2587
   -0.2620
   -1.0492
    0.4058
    0.1204
    0.4830
   -0.0126
    0.3500
   -1.7175
    4.5903
   -2.0720
   -0.0007
   -1.0841
    2.4412
   -1.7072];
 
 x0(1) = x00(1);
 x0(11:end) = x00(11:end);

traj = simulate(sys,[t0 tf],x0);
playback(v,traj,struct('slider',true));

end

