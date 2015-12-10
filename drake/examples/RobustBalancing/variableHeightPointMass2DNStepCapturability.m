function variableHeightPointMass2DNStepCapturability(n)

g = 10;
step_max = .7;
step_time = 0.3;
z_nom = 1;
R_diag = [2, 2 2, 2];

scale = 1;
g = g/scale;
z_nom = z_nom/scale;
step_max = step_max/scale;
R_diag = R_diag/scale;

f_max = 1.1;
f_min = .9;

model = VariableHeightPointMass2D(g, z_nom, step_max, step_time, f_max, f_min);

if n > 0
  T = step_time;
else
  T = 1;
end
options.degree = 4;
options.do_backoff = false;
options.backoff_ratio = 1.05;

% R_diag = 2 * ones(1, model.num_states);

% goal_radius = 0.01;
% target = @(x) goal_radius^2 - x'*x;
target = [];

nStepCapturabilitySOS(model, T, R_diag, target, n, options)

end