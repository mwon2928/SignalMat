function dx_dt = testReactions(t,x,type,k,v)

switch type
    case 'syn'
        % Synthesis k = [1]
        dx_dt(1) = k(1);
    case 'uni'
        % Dissociation: k = [1 0 0 0]
        % Interconversion k = [0 1 0 0]
        % Degradation:  k = [0 0 1 0]
		% SynMM: k = [0 0 0 1]
        dx_dt(1) = (-(k(1)+k(2)+k(3))*x(1)+k(4)*x(2))*v(1)/v(1);
        dx_dt(2) =  (k(1)+k(2))*x(1)*v(1)/v(2);
        dx_dt(3) =  k(1)*x(1)*v(1)/v(1);
    case 'bi'
        % Association:             k = [1 0 0]
        % MM Enzyme Kinetic:       k = [0 1 0]
        % MM enzyme Kinetic Deg:   k = [0 0 1]
		vOverlap = min(v);
        dx_dt(1) = -k(1)*x(1)*x(2)*vOverlap/v(1) - k(2)*x(1)*x(2)*vOverlap/v(1) - k(3)*x(1)*x(2)*vOverlap/v(1);
        dx_dt(2) = -k(1)*x(1)*x(2)*vOverlap/v(2);
        dx_dt(3) =  k(1)*x(1)*x(2)*vOverlap/v(2) + k(2)*x(1)*x(2)*vOverlap/v(2);
    case 'enzQSSA'
        %k(1-3) is the forward. k(4-6) is the reverse.
		vOverlap = min(v);
        dx_dt(1) = -k(1)*x(1)*x(2)+k(2)*x(5)+k(6)*x(6)*vOverlap/v(1);
        dx_dt(2) = -k(1)*x(1)*x(2)+k(2)*x(5)+k(3)*x(5);
        
        dx_dt(3) = -k(4)*x(3)*x(4)+k(5)*x(6)+k(3)*x(5)*vOverlap/v(2);
        dx_dt(4) = -k(4)*x(3)*x(4)+k(5)*x(6)+k(6)*x(6);
		
		dx_dt(5) =  k(1)*x(1)*x(2)-k(2)*x(5)-k(3)*x(5)*vOverlap/v(1);
        dx_dt(6) =  k(4)*x(3)*x(4)-k(5)*x(6)-k(6)*x(6)*vOverlap/v(2);
		
	case 'hillFun'
		vOverlap = min(v);
		dx_dt(1) = -k(1)*x(1)*x(3).^k(3)/(k(2)+x(3).^k(3))*vOverlap/v(1)+k(4)*x(2)*v(2)/v(1);
        dx_dt(2) =  k(1)*x(1)*x(3).^k(3)/(k(2)+x(3).^k(3))*vOverlap/v(2)-k(4)*x(2)*v(2)/v(2);
		dx_dt(3) = 0;
end

dx_dt(7) = 0;
dx_dt = dx_dt';