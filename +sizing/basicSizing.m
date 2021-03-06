clear;
close all;
clc;

% Iterate until isolator exit pressure is balanced
i_err = inf;
i_maxErr = 100; % [Pa]
Pmin = 40000; % [Pa] First guess at isolator exit pressure

% Assume 600 lb / 272 kg total mass
m_vehicle = 272; % kg

phis = 0.516;
M0 = 6.5; % Free stream Mach
q = 1500 * 47.8802589; % [Pa]
mdot_air = 3.4; % [kg/s] Air mass flow rate
coneAngle = 5; % [deg] Inlet cone half angle
M2 = (1/2) * M0; % Isolator exit mach
tsteps = 1000; % Number of integration steps

% Combustor
D_outer = 0.2035; % [m]
D_inner = 0.16; % [m]
A_comb = pi * ((D_outer / 2)^2 - (D_inner / 2)^2);

if numel(phis) > 1
    waitString = @(x) sprintf('%0.1f%% Complete', x * 100);
    wh = waitbar(0, waitString(0));
end

for p_i = 1:numel(phis)
    if numel(phis) > 1
        num = ((p_i - 0.5) / numel(phis));
        waitbar(num, wh, waitString(num));
    end
    phi = phis(p_i);
    
    cea = nasa.CEARunner();
    i_err = inf;
    P2 = Pmin;
    while (abs(i_err) > i_maxErr)
        
        P2 = 0.9 * (Pmin - P2) + P2; % [Pa] Isolator exit static pressure
        
        % Inlet sizing
        [inletDiameter, inletGap, inletSystemLength, T2, Pr_inlet, Pr_is, altitude, P0, T0, coneLength, u0, Tt] = inlet.genInlet(M0, q, mdot_air, M2, P2, coneAngle);
        A_isolator = pi * ((inletDiameter / 2)^2 - ((inletDiameter - (inletGap))/2)^2);
        if (Pr_is >= 1)
            warning('Invalid design! Isolator recovery pressure too high');
        end
        A_star_2 = A_isolator / aeroBox.isoBox.calcARatio(M2, 1.4);
        % Inlet area
        areaInlet = pi * (inletDiameter / 2)^2;
        aInlet = sqrt(1.4 * 287 * T0); % Sonic velocity at inlet
        uInlet = aInlet * M0; % Velocity at inlet
        ramDrag = mdot_air * uInlet;
        
        P0_2 = aeroBox.isoBox.calcStagPressure('mach', M2, 'gamma', 1.4, 'Ps', P2);
        M3 = aeroBox.isoBox.machFromAreaRatio(A_comb / A_star_2, 1.4, 1);
        P3 = aeroBox.isoBox.calcStaticPressure('mach', M3, 'gamma', 1.4, 'Pt', P0_2);
        T3 = aeroBox.isoBox.calcStaticTemp('mach', M3, 'gamma', 1.4, 'Tt', Tt);
        Pmin_guess = P3; % [Pa] Initial guess at minimum chamber pressure
        
        numDets = 1; % Number of detonation waves (keep at 1 for basic sizing noone really understands it anyways)
        
        
        % Iterate until minimum chamber pressure is balanced
        c_err = inf;
        c_maxErr = 100; % [Pa]
        c_step = 10000;
        c_lastDir = 1;
        while abs(c_err) > c_maxErr && c_step > 1
            % Get CEA detonation parameters
            params = cea.run('problem', 'det', 'p,atm', Pmin_guess / 101325, 't,k', T3, ...
                'phi', phi, 'output', 'trans', 'reac', 'fuel' ,'C2H4', 'wt%', 100, 'oxid', ...
                'Air', 'wt%', 100, 'end');
            R = 8314 / params.output.burned.mw;
            Pr = params.output.p_ratio;
            Tr = params.output.t_ratio;
            v_cj = params.output.det_vel;
            gamma_det = params.output.burned.gamma;
            Tmax = T2 * Tr; % [K] Temperature of burned gas
            [Isp, F, Pmin] = combustor.solveRDE(Pr, Pmin_guess, Tmax, v_cj, R, D_outer, D_inner, mdot_air, phi, gamma_det, tsteps, P0, numDets, M2);
            
            c_err = Pmin - Pmin_guess; % Pressure guess error
            
            if c_lastDir ~= sign(c_err)
                c_step = min(c_step / 2, abs(c_err));
            end
            
            c_lastDir = sign(c_err);
            
            Pmin_guess = Pmin_guess + sign(c_err) * c_step;
        end
        
        i_err = P3 - Pmin;
        
    end
    
    % Vehicle size
    b = 24; % [in] Wingspan
    c_r = 90; % [in] Root chord
    c_t = 30; % [in] Tip chord
    w_lb = 600; % [lb] Vehicle Weight
    w_kg = w_lb * 0.453592; % [kg] Vehicle Wieght
    
    q_psf = q / 47.8802589;
    q_psi = q_psf / 144;
    [LoD, Cl, Cd, Area] = VehicleBasicParameters.getLoD(q_psf, M0, b, c_r, c_t, w_lb);
    
    totalThrust = (F - ramDrag);
    drag = q_psi * Area * Cd * 4.44822; % N
    lift = q_psi * Area * Cl * 4.44822; % N
    
    T_w = (m_vehicle * 9.81) / totalThrust;
    
    p_Thrust(p_i) = totalThrust;
    p_Tmax(p_i) = Tmax;
    p_Drag(p_i) = drag;
    p_Lift(p_i) = lift;
    
    if numel(phis) == 1
        fprintf('Flight at M = %0.2f, u = %0.3f m/s, q = %0.3f psf\n', M0, u0, q_psf);
        fprintf('Operating at %0.3f km and a pressure recovery of %0.3f\n', altitude / 1e3, Pr_inlet);
        fprintf('Inlet diameter of %0.3f m\n', inletDiameter);
        fprintf('Combustion chamber outer diameter of %0.3f m\n', D_outer);
        fprintf('Isp: %0.2f s\nMinimum chamber pressure: %0.3f kPa\n', Isp, Pmin / 1000);
        fprintf('Total Thrust: %0.3f kN\n', totalThrust / 1000);
        fprintf('Weight to Thrust ratio of %0.2f\n', T_w);
        fprintf('Lift to Drag ratio of %0.2f\n', LoD);
        fprintf('Excess Thrust: %0.3f N\n', totalThrust - drag);
        fprintf('Excess Lift: %0.3f N\n', lift - w_kg * 9.81);
        fprintf('Accelerating at %0.3f m/s^2\n', (totalThrust - drag) / w_kg);
    end
end

if numel(phis) > 1
        close(wh);
    
    
    figure;
    plot(phis, p_Tmax);
    xlabel('Equivalence Ratio');
    ylabel('Max Combustor Temperature (K)');
    title('Temperature v. Equivalence Ratio');
    
    figure;
    plot(phis, p_Thrust / 1000);
    hold on;
    plot(phis, p_Drag / 1000);
    legend('Thrust', 'Drag');
    xlabel('Equivalence Ratio');
    ylabel('Thrust (kN)');
    title('Thrust v. Equivalence Ratio');
    

    
    % Determine the operating point
    [phi_eq, thrust_eq] = util.intersections(phis, p_Thrust, phis, p_Drag, 1);
    fprintf('SLF at phi=%0.3f, thrust = %0.3f kN\n', phi_eq, thrust_eq / 1000);
    plot(phi_eq, thrust_eq / 1000, 'rx');
end



