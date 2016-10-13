function [t,Y,YComp,modelRaw] = findTC(modelRaw,tspan,varargin)
% findTC Simulates the system models described by SigMat models
%	[TOUT,YOUT,YCOUT,MODELOUT] = findTC(MODEL,TSPAN,'opt1',vals,...)
%	with TSPAN = [T0 TFINAL] of the SigMat MODEL. MODEL can either be a
%	preparsed '.m' file or a postparsed structure. findTC returns TOUT,
%	which is a vector of time points. YOUT, a matrix where each column is
%	the response of each system node at the given time points. YOUT
%	dissociates complexes in the system. YCOUT on the other hand keeps
%	complexes associated. MODELOUT outputs the postparsed structure of the
%	simulated model.
%
%	Possible options, their meaning and corresponding values are:
%	p   - parameter set. Val is a vector.
%	y0  - initial concentration conditions. Val is a vector. Note this 
%		  overrides p is any p's are also concentrations.
%	inp - System inputs/perturbations. Val can take one of four forms:
%		  1) {'Species',Val} - The species with the same name in the model 
%            file will have 'Val' injected on simulation start (after basal
%            if relevant).
%		  2) {'Species',function_handle} - The species with the same name 
%		     in the model will have an additional rate of change given by 
%		     function_handle applied to its concentration.
%		  3) Vector of values - Denotes a step increase in concentration at
%		     time equal zero for each species by the amount given in the
%		     species corresponding index in the vector. I.e. if the model
%		     has species 'A' and 'B', a vector of [1, 2] would imply an
%		     initial increase of A = 1 and B = 2. Species indexation can be
%		     found in modelout.modSpc.name.
%		  4) Function handle - A time dependent function handle that 
%			 outputs a time dependent vector describing an additional rate
%			 of change applied to all species. Again vector indexation
%			 correspondings with species indexation.
%	-b  - prevent basaling period prior to run. No val needed.
%	-r  - prevent "ramp" period prior to run (like a basaling period but
%	      for complex formation). No val needed.
%	odeopts - ode options. Val is generated by odeset.
%	errDir  - Directory to save run errors. Val is a string containing the
%			  target directory.
%	errShow - Whether to bypass errors or throw errors in ode solving
%	          process (default = false).

%% To Implement
% Solver choice in options

%% Code to handle options
% Option names
Names = ['p       '
         'inp     '
         '-r      '
		 'y0      '
		 'odeopts '
	     'errDir  '
		 '-b      '
		 'errShow '];
     
%Initialise potental options
p    = [];
x0   = [];
tmpInp  = [];
noRamp = false;
errDir = false;
noBasal = false;
errShow = false;

detectOpts = true;
%Parse optional parameters (if any)
for ii = 1:length(varargin)
	if detectOpts %only enter loop if varargin{ii} is a parameter
		detectOpts = false;
		switch lower(deblank(varargin{ii}))
			case lower(deblank(Names(1,:)))   %Parameters
				p = varargin{ii+1};
			case lower(deblank(Names(2,:)))   %Input
				tmpInp = varargin{ii+1};
			case lower(deblank(Names(3,:)))   %No initial ramping
				noRamp = true;
				detectOpts = true;
			case lower(deblank(Names(4,:)))   %Initial conditions
				x0 = varargin{ii+1};
			case lower(deblank(Names(5,:)))   %Ode options
				options = varargin{ii+1};
			case lower(deblank(Names(6,:)))   %Set directory for error output
				errDir = varargin{ii+1};
			case lower(deblank(Names(7,:)))   %No basal
				noBasal = true;
				detectOpts = true;
			case lower(deblank(Names(8,:)))   %Show error
				errShow = varargin{ii+1};
			case []
				error('Expecting Option String in input');
			otherwise
				error('Non-existent option selected. Check spelling.')
		end
	else
	        detectOpts = true;
	end
end

modelRaw = parseModel(modelRaw,'reparse',false);

% %Correct dimension of x0 and tspan
if isrow(x0)
    x0 = x0';
end
if isrow(tspan)
    tspan = tspan';
end

% Work out length of species
nx = length(modelRaw.modSpc.matVal);

%% Determining input values
inpConst = zeros(nx,1);
inpFun = @(t)zeros(nx,1);
%Input values: make all into either function handles or vectors
% This component looks at the experiment-simulation name pair, then
% compares the experiment name with the name given in the 
if iscell(tmpInp) % state_name--val pair
	if size(tmpInp,1)>1
        error('findTC:TooManyStateValPair','Only one state function-handle pair allowed. Create an external function and pass it instead')
	end
	% Match input state
	protList = modelRaw.modSpc.name;
	[~,stateInd] = intersect(upper(protList),upper(tmpInp{1,1})); 
	%Insert constant values or function handle
	if isnumeric(tmpInp{1,2})
		inpConstInd = ones(nx,1);
		inpConst(stateInd) = tmpInp{1,2};
	else
		inpVec = zeros(length(protList),1);
		inpVec(stateInd) = 1;
		inpFun = @(t) inpVec*tmpInp{1,2}(t);
	end
elseif isa(tmpInp,'function_handle') %vector of function handles
	[a,b] = size(tmpInp(1));
	if b>1
		if a~=1
			error('findTC:inpfunDimWrong','Dimensions of input function handle is wrong.')
		end
		if b <= nx
			inpFun = @(t) [tmpInp(t)';zeros(nx-b,1)];
		else
			error('findTC:tooManyInpState','Too many input states in vector-val method.')
		end
	elseif b==1
		if a <= nx
			inpFun = @(t) [tmpInp(t);zeros(nx-a,1)];
		else
			error('findTC:tooManyInpState','Too many input states in vector-val method.')
		end
	else
		error('findTC:inpfunDimWrong','Dimensions of input function handle is wrong.')
	end
elseif size(tmpInp,2)==2 && isnumeric(tmpInp)    %Ind val pair
	inpConst(tmpInp(:,1)) = tmpInp(:,2);
elseif min(size(tmpInp))==1 && isnumeric(tmpInp) %vector of spiked final concentration
	[a,b] = size(tmpInp);
	if a == 1
		tmpInp = tmpInp';
		a = b;
	end
	if a > nx
		error('findTC:tooManyInpState','Too many input states in vector-val method.')
	end
	inpConst = [tmpInp;zeros(nx-a,1)];
elseif size(tmpInp,2)>2
	error('odeQSSA:inpArrayDimWrong','Dimension of system input incorrect. Check your inputs')
elseif ~isempty(tmpInp)
	error('odeQSSA:inpArrayClassWrong','Class of external input function invalid. Check your inputs')
end

%% non-dimensionalisation of time
normInp = @(t) inpFun(t*(tspan(end)-tspan(1))+tspan(1))*(tspan(end)-tspan(1)); %non-dimensionalise inp;

[modelOut,modelRamp] = insParam(modelRaw,p,tspan,normInp);

% Replace x0 if not passed as an input
if isempty(x0)
	x0 = modelOut.modSpc;
else
	if length(x0)~=length(modelOut.modSpc)
		x0(length(modelOut.modSpc)) = 0; %pad out the vector with zeros if necessary
	end
end

%ODE Solver options and warning
if ~exist('options','var')
	options = odeset('relTol',1e-6,'NonNegative',ones(size(x0)));
end
warnstate('error')

doInteg = true;
norm_tspan = [0 5];
%% Solving
% Ramping
if ~noRamp
	if noBasal
		%Do not basal the time course. Set all rate parameters to zero.
		modelRamp.sigma = @(t) (inpConst+x0)*2*normpdf(t,0,0.2);
	else
		%Initial basal
		%Enter the single input at the end of the time course
		modelRamp = modelOut;
		modelRamp.sigma = @(t) x0*2*normpdf(t,0,0.2);
	end
	modelRamp.time = tic;
	dx_dt = @(t,x) modelRaw.rxnRules('dynEqn',t,x,modelRamp);
	Y = x0'*0;
	t = [0 10];
	delXCond = true; %Difference between last 5 points condition (if smaller than machine error, than equivalent to no change)
	dxdtCond = true; %Rate of change condition. If zero then by definition equilibrium reached
	try
		while delXCond && dxdtCond
			y0 = Y;
			[t,Y] = ode15s(dx_dt,t,y0,options);
			delXCond = abs(sum((Y(end-5,:)-Y(end,:))/max(Y(end-1,:)))) > eps;
			Y = Y(end,:);
			dxdtCond = sum(abs(dx_dt(t(1),Y'))) > eps;
			t = [t(end) 10*t(end)];
		end
		Y(abs(Y*max(Y))<eps) = 0; %Make scaled values that are smaller than machine error zero
	catch errMsg
		t = [0 norm_tspan(2)];
		if errDir && ~errShow
			storeError(modelRaw,x0,p,errMsg,errMsg.message,errDir)
		elseif ~errShow
			storeError(modelRaw,x0,p,errMsg,errMsg.message)
		elseif errShow
			rethrow(errMsg)
		end
		Y = nan(length(norm_tspan),length(x0));
		doInteg = false;
	end
	y0 = Y(end,:);
	y0(y0<0) = 0;
else
	y0 = x0;
end

%Run
if ~noBasal
	modelOut.sigma = @(t) modelOut.sigma(t) + inpConst*2*normpdf(t,0,1e-6);
end

modelOut.time = tic;
dx_dt = @(t,x) modelRaw.rxnRules('dynEqn',t,x,modelOut);

failedOnce = false;
while doInteg
	try
		[t,Y] = ode15s(dx_dt,norm_tspan,y0,options);
		doInteg = false;
	catch errMsg
		% Error catching
		if failedOnce
			t = [0 norm_tspan(2)];
			if errDir && ~errShow
				storeError(modelRaw,x0,p,errMsg,errMsg.message,errDir)
			elseif ~errShow
				storeError(modelRaw,x0,p,errMsg,errMsg.message)
			elseif errShow
				rethrow(errMsg)
			end
			Y = nan(length(norm_tspan),length(x0));
			doInteg = false;
		else
			failedOnce = true;
			norm_tspan = norm_tspan*1.5;
		end
	end
end

t = t*(tspan(end)-tspan(1))+tspan(1); %Restore to original units
if length(tspan)>2
	Y = interp1(t,Y,tspan);
	t = tspan;
else
    rmIndx = find(t>=tspan(end),1,'first');
    Y(rmIndx,:) = interp1(t((rmIndx-1):rmIndx),Y((rmIndx-1):rmIndx,:),tspan(end));
    Y((rmIndx+1):end,:) = [];
    t(rmIndx) = tspan(end);
    t((rmIndx+1):end) = [];
end
YComp  = Y;
Y = compDis(modelOut,YComp);      %dissociate complex
warnstate('on') %Switch warnings back to warnings
end

% ODE Solve warning messages. Turn them into errors so the error catcher
% can catch them.
function warnstate(state)
    warning(state,'MATLAB:illConditionedMatrix');
    warning(state,'MATLAB:ode15s:IntegrationTolNotMet');
    warning(state,'MATLAB:nearlySingularMatrix');
    warning(state,'MATLAB:singularMatrix');
end