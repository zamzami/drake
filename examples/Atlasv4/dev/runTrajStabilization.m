function runTrajStabilization(traj_params,segment_number)

% traj params: 1-fully actuated, periodic; 2-fully actuated, step; 3-spring ankle 
if nargin<1
  traj_params = 1;
end

if nargin < 2
  segment_number = -1; % do full traj
end

if ~checkDependency('gurobi')
  warning('Must have gurobi installed to run this example');
  return;
end

path_handle = addpathTemporary(fullfile(getDrakePath,'examples','Atlasv4'));

options.twoD = true;
options.view = 'right';
options.floating = true;
options.ignore_self_collisions = true;
options.enable_fastqp = false;
if traj_params==1
  s = '../urdf/atlas_simple_planar_contact.urdf';
  traj_file = 'data/atlas_more_clearance_3mode_lqr_sk'; 
  options.terrain = RigidBodyFlatTerrain();
  modes = [8,6,4];
elseif traj_params==2
  s = '../urdf/atlas_simple_planar_contact.urdf';
  traj_file = 'data/atlas_step_and_stop_lqr'; 
  step_height = .1;
  options.terrain = RigidBodyLinearStepTerrain(step_height,.35,.02);
  modes = [8,3,4,4,1]; % step
elseif traj_params==3
  s = '../urdf/atlas_simple_spring_ankle_planar_contact.urdf';
  traj_file = 'data/atlas_passiveankle_traj_lqr_zoh.mat';
  %traj_file = 'data/atlas_passiveankle_traj_lqr_090314_zoh.mat';
  options.terrain = RigidBodyFlatTerrain();
else
  error('unknown traj_params');
end

w = warning('off','Drake:RigidBodyManipulator:UnsupportedVelocityLimits');
r = Atlas(s,options);
r = r.setOutputFrame(AtlasXZState(r));
r = r.setStateFrame(AtlasXZState(r));
warning(w);

nx = getNumStates(r);
nq = getNumPositions(r);
nu = getNumInputs(r);

v = r.constructVisualizer;
v.display_dt = 0.01;


load(traj_file);

if traj_params~=2
  repeat_n = 2;
  [xtraj,utraj,Btraj,Straj_full] = repeatTraj(r,xtraj,utraj,Btraj,Straj_full,repeat_n,true);
else
  repeat_n = 1;
end

support_times = zeros(1,length(Straj_full));
for i=1:length(Straj_full)
  support_times(i) = Straj_full{i}.tspan(1);
end
% [~,modes] = extractHybridModes(r,xtraj,support_times+0.02); % hack add time to make sure it's fully into the next mode
% 
% figure(23423);
% plot(support_times+0.03,modes,'b.-');
 
options.right_foot_name = 'r_foot';
options.left_foot_name = 'l_foot'; 
%modes = [8,6,3,3,4,4,4,2,7,7,8,8];%,8,6,3,3,4,4];
% modes = [8,6,1,3,4,4,2,1,7,8];
% modes = [8,6,3,4,4,2,7,8];
%modes = [8,6,1,3,4,4,2,1,7,8];


modes = repmat(modes,1,repeat_n);
lfoot_ind = findLinkId(r,options.left_foot_name);
rfoot_ind = findLinkId(r,options.right_foot_name);  

%   mode 1: [left: heel+toe, right: heel+toe]
%   mode 2: [left: heel,     right: heel+toe]
%   mode 3: [left: toe,      right: heel+toe]
%   mode 4: [left: none,     right: heel+toe]
%   mode 5: [left: heel,     right: toe]
%   mode 6: [left: heel+toe, right: heel]
%   mode 7: [left: heel+toe, right: toe]
%   mode 8: [left: heel+toe, right: none]
%   mode 9: [left: toe,      right: heel]
%   mode 10: [left: none,    right: none]
support_states = [RigidBodySupportState(r,[lfoot_ind,rfoot_ind]); ...
  RigidBodySupportState(r,[lfoot_ind,rfoot_ind],struct('contact_groups',{{{'heel'},{'heel','toe'}}})); ...
  RigidBodySupportState(r,[lfoot_ind,rfoot_ind],struct('contact_groups',{{{'toe'},{'heel','toe'}}})); ...
  RigidBodySupportState(r,rfoot_ind); ...
  RigidBodySupportState(r,[lfoot_ind,rfoot_ind],struct('contact_groups',{{{'heel'},{'toe'}}})); ...
  RigidBodySupportState(r,[lfoot_ind,rfoot_ind],struct('contact_groups',{{{'heel','toe'},{'heel'}}})); ...
  RigidBodySupportState(r,[lfoot_ind,rfoot_ind],struct('contact_groups',{{{'heel','toe'},{'toe'}}})); ...
  RigidBodySupportState(r,lfoot_ind); ...
  RigidBodySupportState(r,[lfoot_ind,rfoot_ind],struct('contact_groups',{{{'toe'},{'heel'}}})); ...
  RigidBodySupportState(r,[])];

supports = [];
for i=1:length(modes)
  supports = [supports; support_states(modes(i))];
end

if segment_number<1
  B=Btraj;
  S=Straj_full;
  if iscell(xtraj)
    t0 = xtraj{1}.tspan(1);
    tf = xtraj{length(xtraj)}.tspan(2);
  else
    t0 = xtraj.tspan(1);
    tf = xtraj.tspan(2);
    v.playback(xtraj);%,struct('slider',true));
  end
else
  B=Btraj{segment_number};
  S=Straj_full{segment_number};
  t0 = Btraj{segment_number}.tspan(1);
  tf = Btraj{segment_number}.tspan(2);
  if iscell(xtraj)
    xtraj = xtraj{segment_number};
    utraj = utraj{segment_number};
  end
  xtraj = xtraj.setOutputFrame(getStateFrame(r));
  v.playback(xtraj);%,struct('slider',true));
end

allowable_supports = RigidBodySupportState(r,[lfoot_ind,rfoot_ind]);

ctrl_data = FullStateQPControllerData(true,struct(...
  'B',{B},...
  'S',{S},...
  'R',R,... 
  'x0',{xtraj},...
  'u0',{utraj},...
  'support_times',support_times,...
  'supports',supports,...
  'allowable_supports',allowable_supports));

% instantiate QP controller
options.timestep = .001;
options.dt = .001;
options.cpos_slack_limit = inf;
options.w_cpos_slack = 0.1;
options.phi_slack_limit = inf;
options.w_phi_slack = 0.0;
options.w_qdd = 0*ones(nq,1);
options.w_grf = 0;
options.Kp_accel = 0;
options.contact_threshold = 5e-4; %was 1e-4
options.offset_x = true;
qp = FullStateQPController(r,ctrl_data,options);

% feedback QP controller with Atlas
sys = feedback(r,qp);

S=warning('off','Drake:DrakeSystem:UnsupportedSampleTime');
output_select(1).system=1;
output_select(1).output=1;
sys = mimoCascade(sys,v,[],[],output_select);
warning(S);

% t0 = .418;
% tf = 1;s
if iscell(xtraj)
  x0 = xtraj{1}.eval(t0);
else
  x0 = xtraj.eval(t0);
end
traj = simulate(sys,[t0 tf],x0);
playback(v,traj,struct('slider',true));

if 1
  traj_ts = traj.getBreaks();
  traj_pts = traj.eval(traj_ts);
  
  if iscell(xtraj)
    xtraj_cell = xtraj;
    xtraj = xtraj_cell{1};
    for i=2:length(xtraj_cell);
      xtraj=xtraj.append(xtraj_cell{i});
    end
  end
  
  xtraj_pts = xtraj.eval(traj_ts);
  
  figure(111);
  for i=1:nq
    subplot(2,5,i);
    hold on;
    title(r.getStateFrame.coordinates{i});
    plot(traj_ts,xtraj_pts(i,:),'g.-');
    plot(traj_ts,traj_pts(i,:),'r.-');
    hold off;
  end
  figure(112);
  for i=1:10
    subplot(2,5,i);
    hold on;
    title(r.getStateFrame.coordinates{nq+i});
    plot(traj_ts,xtraj_pts(nq+i,:),'g.-');
    plot(traj_ts,traj_pts(nq+i,:),'r.-');
    hold off;
  end
end

if 0
  pptraj = PPTrajectory(foh(traj.getBreaks,traj.eval(traj.getBreaks)));
  for i=1:20
    figure(100+i);
    fnplt(xtraj(i));
    hold on;
    fnplt(pptraj(i));
    title(strrep(r.getStateFrame.coordinates(i),'_','\_'));
    hold off;
  end
end
end

