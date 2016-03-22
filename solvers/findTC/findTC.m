function [t,Y,YComp,model,status] = findTC(model,tspan,varargin)
% 
%   [t,Y,YComp,model] = findTC(model,tspan,...)
%   
%   Solve for timecourse with:
%       > model : Function handle of topology file string of .m file. Can
%				  also be a function handle to an ODE15s file.
%       > tspan : Timespan.
%
%	If using an ODE15s type file, pass inputs as with a normal matlab ode
%	solver.
%
%	If using a QSSA type file, the following rules apply.
%
%   Optional inputs are passed as parameter/value pairs
%       > y0    : Initial condition. Optional input. If not entered, will
%                 find from the topology file. If a custom topology is
%                 used, this must be included.
%       > p     : parameters. An either be a vector of numbers, of a struct
%                 containing the necessary tensors (in form generated by
%                 makeTens).
%       > inp   : Control inputs of system. Can be inputted in two ways:
%                 > Ind-val pair: Index and value pairs. Index determins
%                                 the species and val defines (explained  
%				                  after val vector part down) the input. 
%							      Index can either be:
%				                       > the name of the states, in which
%				                         case enter as cell pairs:
%										 {'name1',val1;'name2',val2}
%									     this is more convenient but
%									     slower.
%									   > the numerical index of the states,
%									     in which case enter as an array:
%										 [ind,val;ind,val]
%									     this is requires knowing the order
%									     of your states but is quicker.
%                 > Val vector : Vector of equal length to x0 (which
%								 excludes non-complexed states). If
%								 non-complex states are included they will
%								 be padded with zeros. E.g.
%								 vec = [0 val1 0 0 val2]
%								 
%                 > Val definition: The val in the input determines how the
%									inputs are applied. Where "val" is
%									required, it can either be a constant,
%									which defines a final concentration
%									that is spiked in initially, or a time
%									profile of injection rate which is 
%									added gradually. When using Ind-pair
%									input, these can be mixed. For the
%									Val vector input, all inputs must 
%									either be final concentrations, or
%									injection rate time profiles (needless
%									to say MATLAB does not allow vectors to
%									have a mix of function handles and
%									doubles).
%									
%	Parameter only options
%       > -b    : Basal the system before t = 0.
%       > -r    : No ramping in of initial conditions at all. NOT
%                 RECOMMENDED WHEN MODEL HAS ENZYME KINETIC REACTIONS. Use
%                 only to computationally optimise the simulation process.
%       
%	Outputs are:
%		- t     : Time points
%		- Y     : Simulated time course with complexes dissociated and removed
%		- YComp : Simulated time course with complexes undissociated
%		- model : definition of model as SigMat structure. 
%
%   Program can automatically parse the model using parseModel
%
%   See also parseModel, odeQSSA
%
%   Martin Wong. University of Sydney. 22/03/2016

% Determine if ODE model or QSSA model
modType = modelType(model);
status = 0;
if strcmp(modType,'QSSA-m') || strcmp(modType,'QSSA-sbml')
	[t,Y,YComp,model] = odeQSSA(model,tspan,varargin{:}); 
elseif strcmp(modType,'ode15s')
	%ode15s inputs is assumed to be entered as if using ode15s normally
	if strcmp(varargin{end},'-r') %hack from findSS which sometimes passes an extra '-r' for the odeQSSA case. Must be removed here.
		varargin(end) = [];
	end
	[t,Y] = ode15s(model,tspan,varargin{:});
	YComp = Y;
	status = 0;
else
	error('modelObjective:badModelInput','Invalid model passed. Check inputs')
end
