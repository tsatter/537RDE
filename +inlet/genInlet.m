function [inletDiameter, inletGap, totalLength, T2, Pr_needed, Pr_isolator, altitude, P0, T0, coneLength, u0, Tt] = genInlet(M0, q, mdot, M2, P2, coneAngle)
%GENERATEINLET Summary of this function goes here
%   Detailed explanation goes here
% Preliminary sizeing of inlet, basic calculations

gamma = 1.4; % Ratio of specific heats
R_air = 287.058; % [J/kg*K] Air gas constant

P0 = (2 * q) / (gamma * M0^2); % [Pa] Free stream pressure
Pt0 = aeroBox.isoBox.calcStagPressure('mach', M0, 'Ps', P0, 'gamma', gamma); % [Pa] Free stream stagnation pressure

% Predict altitude

% [Pa] Atmpsheric pressure
altPa = 1e3 * [101.33 99.49 97.63 95.91 94.19 92.46 90.81 89.15 87.49 85.91 85.44 81.22 78.19 75.22 72.40 69.64 57.16 46.61 37.65 30.13 23.93 18.82 14.82 11.65 9.17 7.24 4.49 2.80 1.76 1.12 0.146 2.2e-2 1.09e-6 4.98e-7 4.8e-10];
% [m] Altitude
alth = 0.3048 * [0 500 1000 1500 2000 2500 3000 3500 4000 4500 5000 6000 7000 8000 9000 10000 15000 20000 25000 30000 35000 40000 45000 50000 55000 60000 70000 80000 90000 100000 150000 200000 300000 500000 2000000];

altitude = interp1(altPa, alth, P0);

[T0, P0, rho0] = atmosphere.atmosphere_metric(altitude, 1);

a0 = sqrt(gamma * R_air * T0); % [m/s] Free stream sound speed
u0 = a0 * M0; % [m/s] Free stream velocity
inletArea = mdot / (u0 * rho0);
inletDiameter = sqrt(inletArea / pi) * 2; % [m]
mdot = u0 * inletArea * rho0; % [kgamma/s] Inlet air mass flow

% After shock properties

% calculates the conical shock angle
shockAngle=conical.find_cone_shock_angle(M0,coneAngle,gamma);
% returns the flow field solution for the given cone angle
[v,mn1]=conical.taymacsol2(M0,shockAngle,gamma);
% output and answer handling script
% resolves the radial and angular velocity components into a % single ray velocity value
vdash=sqrt((v(:,1).^2)+(v(:,2).^2));
% converts the velocity values into Mach numbers
mach=sqrt(2./(((vdash.^(-2))-1).*(gamma-1)));
% find the Mach number of the ray nearest the cone
M1=mach(length(mach));  
% calculates the Temperature ratio for the ray nearest the cone
To_T=1+(((gamma-1)/2).*M1.^2);
% calculates the Pressure ratio for the ray nearest the cone
Po_P=(1+(((gamma-1)/2).*M1.^2)).^(gamma/(gamma-1));
% calculates the Density ratio for the ray nearest the cone
rho_rh=(1+(((gamma-1)/2).*M1.^2)).^(1/(gamma-1));
% Calculated the Stagnation pressure ratio (after/before conical shock)
Po2_Po1=((((gamma+1)/2.*mn1.^2)./(1+(((gamma-1)/2).*mn1.^2))).^(gamma/(gamma-1)))./...
    ((((2*gamma/(gamma+1)).*mn1.^2)-((gamma-1)/(gamma+1))).^(1/(gamma-1)));


% Get density behind the shock
turnAngle = shockAngle;
rho1 = rho0 * (((gamma + 1) * M0^2 * sind(turnAngle)^2) / ((gamma - 1) * M0^2 * sind(turnAngle)^2 + 2));
T1 = T0 * (((2 * gamma * M0^2 * sind(turnAngle)^2 - (gamma - 1)) * ((gamma - 1) * M0^2 * sind(turnAngle)^2 + 2)) / ((gamma + 1)^2 * M0^2 * sind(turnAngle)^2));
Tt = aeroBox.isoBox.calcStagTemp('mach', M0, 'gamma', gamma, 'Ts', T0);
a1 = sqrt(gamma * R_air * T1);
u1 = M1 * a1;
% Find the area needed for this flow
inletEndArea = mdot / (u1 * rho1);

% Find inner diameter
inletInnerDiameter = inletDiameter - 2 * (sqrt(inletEndArea / pi));
inletGap = (inletDiameter - inletInnerDiameter) / 2;
isolatorLength = 9 * inletGap;
coneLength = (inletDiameter / 2) / tand(shockAngle);
totalLength = coneLength + isolatorLength;
% Recovery pressure

% Isolator
Pt2 = aeroBox.isoBox.calcStagPressure('mach', M2, 'Ps', P2, 'gamma', gamma);
Pr_needed = Pt2 / Pt0;
Pr_isolator = Pr_needed / Po2_Po1;
T2 = aeroBox.isoBox.calcStaticTemp('mach', M2, 'Tt', Tt, 'gamma', gamma);

end

