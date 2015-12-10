classdef NStepCapturabilityController < DrakeSystem
  
  properties
    dVdotdu_coeffs
    dVdotdu_pows
    sos_plant
    dVdotdu_interp_bound = 1e-3;
  end
  
  methods
    function obj = NStepCapturabilityController(plant,dVdotdu_coeffs,dVdotdu_pows)
      sos_plant = plant.sos_plant;
      obj = obj@DrakeSystem(0,0,sos_plant.num_states,sos_plant.num_inputs);
      obj.dVdotdu_coeffs = dVdotdu_coeffs;
      obj.dVdotdu_pows = dVdotdu_pows;
      obj.sos_plant = sos_plant;
      obj = obj.setOutputFrame(plant.getInputFrame);
      obj = obj.setInputFrame(plant.getOutputFrame);
    end
    
    function u = output(obj,t,~,x)
      dVdotdu = obj.dVdotdu_coeffs*prod(repmat([t;x]',length(obj.dVdotdu_coeffs),1).^obj.dVdotdu_pows,2);
      
      % incorporate input limits
      [umin, umax, A] = obj.sos_plant.simpleInputLimits(x);
      if isempty(A)
        % use umin, umax
        u = zeros(length(dVdotdu),1);
        for i=1:length(dVdotdu),
          
          if abs(dVdotdu(i)) < obj.dVdotdu_interp_bound
            % interpolate between the two
            u = interp1([-obj.dVdotdu_interp_bound;obj.dVdotdu_interp_bound], [umin(i);umax(i)],dVdotdu(i));
          else
            if dVdotdu(i) < 0
              u(i) = umin(i);
            else
              u(i) = umax(i);
            end
          end
        end
      else
        %u'Au <= 1
        u = A\dVdotdu;
        u = u/sqrt(u'*A*u);
        
        if norm(dVdotdu) < obj.dVdotdu_interp_bound
          u = u * norm(dVdotdu)/(obj.dVdotdu_interp_bound);
        end
      end
    end
  end
  
end
