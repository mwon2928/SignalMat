function [p,mergeModel] = mergeParam(mergeModel,varargin)
% mergeParam Combine parameters from different SIGMAT model parameter sets.
%	[POUT,MERGEMODEL] = mergeParam(MODELIN,DAT1,DAT2,...) with POUT a 
%	vector equal to number of parameters required by SIGMAT modelm MODELIN.
%	MODELIN can be a string, a cell vector of strings or a structure (same 
%	as the input of PARSEMODEL). Remaining input arguments contain data 
%	sets generated by  MCMC with an extra field DAT1.MODEL containing an 
%   output from  PARSEMODEL. MERGEMODEL will be a parsed version of MODELIN
%
%	POUT is a vector of parameters that can be used with MODELIN, with the
%	parameter values taken from all the input data sets. This function will
%	match the parameter descriptions from data sets to the parameter
%	descriptions in MODELIN and place them in the correct position in POUT,
%	The algorithm will prioritise parameters from data sets placed earlier
%	in the list of function arguments (i.e. if DAT1 and DAT2 contain
%	parameters with the same description, DAT1's parameter will override
%	the one from DAT2). To prevent this, set DAT1's row of parameters to
%	NaN.
%
%	The row that will be chosen from the data set DATs are by default the
%	row with the lower DAT.logP. However, it is possible to customise this.
%	To do this, instead of directly putting the MCMC results into DAT, put
%	DAT = {result,irow} where result is the MCMC output and irow is the row
%	to be chosen.

mergeModel = parseModel(mergeModel);
p = NaN(size(mergeModel.pFit.lim(:,1)));

% Make all rows in mergeModel's parameter descriptions row characters
% (strings)
for ii = 1:length(p)
	mergeModel.pFit.desc{ii} = parseStr(mergeModel.pFit.desc{ii});
end

for ii = length(varargin):-1:1
	subDat = varargin{ii};
	if iscell(subDat) % If the varargin is a cell and contains two elements, then the input contains a model and an index for row to pick of parameter list
		if length(subDat) ~= 2
			error('mergeParam:TooManyElementsInData',['There are too many elements given in the cell in input argument ' num2str(ii+1) '.'])
		end
		irow = subDat{2};
		subDat = subDat{1};
	elseif isstruct(subDat)
		irow = find(subDat.logP == min(subDat.logP),1);
	else
		error('mergeParam:UnidentifiedDataType',['Cannot parse data of type ' class(varargin{ii}) ' in input argument ' num2str(ii+1) '.'])
	end
	for jj = 1:length(subDat.model.pFit.desc)
		subDat.model.pFit.desc{jj} = parseStr(subDat.model.pFit.desc{jj});
	end
	[~,I_merged,I_sub] = intersect(mergeModel.pFit.desc,subDat.model.pFit.desc);
	I_sub(isnan(subDat.pts(irow,I_sub))) = [];
	p(I_merged) = subDat.pts(irow,I_sub);
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Sub functions begin %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function outStr = parseStr(inStr)
	outStr = inStr';
	outStr = outStr(:)';
	% Remove anything before the first pipe (always marks number)
	I = strfind(outStr,'|');
	outStr(1:I(1)) = [];
	% Remove all blanks
	I = strfind(outStr,' ');
	outStr(I) = [];
end