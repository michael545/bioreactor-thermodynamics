% --- Script to Run Batch Reactor Simulation with PID Output Plots ---

% 1. Simulation Parameters
simulink_model_name = 'sarzni_reaktor_old'; % Your Simulink model file name
T_ref = 50;                   % Value for the reference temperature
tSim = 30000;                            % Simulation time in seconds (adjust as needed)

disp(['--- Starting Simulation: ', simulink_model_name, ' for ', num2str(tSim), ' seconds ---']);
disp(['Setting T_ref in Simulink (via workspace variable T_ref) to: ', num2str(T_ref), ' deg C']);

assignin('base', 'T_ref', T_ref);

% 3. Run Simulation
try
    out = sim(simulink_model_name, 'StopTime', num2str(tSim));
    disp('--- Simulation Finished Successfully ---');
catch ME
    disp('!!! SIMULATION FAILED !!!');
    disp(['Error message: ', ME.message]);
    % Display stack trace for more detailed debugging
    for i=1:length(ME.stack)
        disp(['File: ', ME.stack(i).file, ', Name: ', ME.stack(i).name, ', Line: ', num2str(ME.stack(i).line)]);
    end
    return; % Stop script if simulation fails
end

% 4. Extract Data
disp('--- Extracting Data ---');
try
    % Ensure "To Workspace" blocks in Simulink are named as expected
    % and "Save format" is Timeseries.
    time_Reactor_T   = out.T.Time;
    data_Reactor_T   = out.T.Data;

    time_Jacket_Pizh = out.T_Pizh.Time;
    data_Jacket_Pizh = out.T_Pizh.Data;

    time_k_valve     = out.k_valve.Time; % Saturated k
    data_k_valve     = out.k_valve.Data;

    time_on_off_input= out.on_off_input.Time;
    data_on_off_input= out.on_off_input.Data;

    % Extract PID controller outputs
    time_PID_EXTERNAL = out.PID_EXTERNAL.Time; % Output of Outer PID (raw T_Pizh_ref)
    data_PID_EXTERNAL = out.PID_EXTERNAL.Data;

    time_PID_INTERNAL = out.PID_INTERNAL.Time; % Output of Inner PID (raw k)
    data_PID_INTERNAL = out.PID_INTERNAL.Data;
    
    % Extract T_reference if saved from Simulink (optional, for plotting)
    if isfield(out, 'T_reference') && isa(out.T_reference, 'timeseries')
        time_T_reference = out.T_reference.Time;
        data_T_reference = out.T_reference.Data;
    else
        % If T_reference is not saved from Simulink, we'll use T_ref for plotting
        time_T_reference = [0; tSim]; % Create a simple time vector for the constant line
        data_T_reference = [T_ref; T_ref];
        disp('Note: T_reference signal not found in Simulink output, plotting script-defined constant T_ref.');
    end


    disp('Data extracted.');
catch ME_extract
    disp('!!! ERROR EXTRACTING SIMULATION DATA !!!');
    disp('Please ensure Simulink "To Workspace" blocks are correctly named:');
    disp('  "T", "T_Pizh", "k_valve", "on_off_input", "PID_EXTERNAL", "PID_INTERNAL"');
    disp('  (and optionally "T_reference")');
    disp('and their "Save format" is set to Timeseries.');
    disp(['Specific error: ', ME_extract.message]);
    return;
end
time_T_reference = out.T_reference.Time;
data_T_reference = out.T_reference.Data;
% --- Plot Results ---
disp('--- Plotting Results ---');
figure('Name', ['Batch Reactor Detailed Results: ' simulink_model_name], 'NumberTitle', 'off', 'WindowState', 'maximized');

% Plot 1: Temperatures (T_ref, T, T_Pizh)
subplot(5,1,1); % Now 5 rows, 1st plot
plot(time_T_reference, data_T_reference, 'g--', 'LineWidth', 1.5, 'DisplayName', 'T_{ref}');
hold on;
plot(time_Reactor_T, data_Reactor_T, 'r-', 'LineWidth', 1.5, 'DisplayName', 'T (Reactor Core)');
plot(time_Jacket_Pizh, data_Jacket_Pizh, 'b-.', 'LineWidth', 1.5, 'DisplayName', 'T_{Pizh} (Jacket Outlet)');
hold off;
title('Temperature Profiles');
xlabel('Time (s)');
ylabel('Temperature (°C)');
legend('show', 'Location', 'best');
grid on;
xlim([0 tSim]);

% Plot 2: Mixing Valve Position (k) - Saturated
subplot(5,1,2); % 2nd plot
plot(time_k_valve, data_k_valve, 'm-', 'LineWidth', 1.5, 'DisplayName', 'k (Saturated)');
title('Mixing Valve Position (k) - Saturated Output');
xlabel('Time (s)');
ylabel('Valve Position k (0-1)');
legend('show', 'Location', 'best');
grid on;
ylim([-0.1 1.1]);
xlim([0 tSim]);

% Plot 3: On/Off Valve Input Signal
subplot(5,1,3); % 3rd plot
plot(time_on_off_input, data_on_off_input, 'k-', 'LineWidth', 1.5, 'DisplayName', 'On/Off Signal');
title('On/Off Valve Input Signal (to Reactor)');
xlabel('Time (s)');
ylabel('Signal Value');
yticks_vals = unique(data_on_off_input);
yticks_labels = cell(size(yticks_vals));
for i = 1:length(yticks_vals)
    if yticks_vals(i) == 1
        yticks_labels{i} = 'Hot (T_V)';
    elseif yticks_vals(i) == -1
        yticks_labels{i} = 'Cold (T_H)';
    else
        yticks_labels{i} = num2str(yticks_vals(i));
    end
end
if length(yticks_vals) > 1 
    set(gca, 'YTick', yticks_vals, 'YTickLabel', yticks_labels);
end
ylim_min = min([-1.2, min(data_on_off_input)-0.2]);
ylim_max = max([1.2, max(data_on_off_input)+0.2]);
ylim([ylim_min ylim_max]);
legend('show', 'Location', 'best');
grid on;
xlim([0 tSim]);

% Plot 4: Outer PID Controller Output (Raw T_Pizh_ref) - NEW
subplot(5,1,4); % 4th plot
plot(time_PID_EXTERNAL, data_PID_EXTERNAL, 'c-', 'LineWidth', 1.5, 'DisplayName', 'Outer PID Output (Raw T_{Pizh,ref})');
hold on;
% Plot the saturation limits for T_Pizh_ref (10 and 60)
plot([0 tSim], [10 10], 'k:', 'DisplayName', 'T_{Pizh,min}');
plot([0 tSim], [60 60], 'k:', 'DisplayName', 'T_{Pizh,max}');
hold off;
title('Outer PID Controller Output (Raw T_{Pizh,ref})');
xlabel('Time (s)');
ylabel('Temperature (°C)');
legend('show', 'Location', 'best');
grid on;
xlim([0 tSim]);

% Plot 5: Inner PID Controller Output (Raw k) - NEW
subplot(5,1,5); % 5th plot
plot(time_PID_INTERNAL, data_PID_INTERNAL, 'color', [0.9290 0.6940 0.1250] , 'LineWidth', 1.5, 'DisplayName', 'Inner PID Output (Raw k)'); % Orange color
hold on;
% Plot the saturation limits for k (0 and 1)
plot([0 tSim], [0 0], 'k:', 'DisplayName', 'k_{min}');
plot([0 tSim], [1 1], 'k:', 'DisplayName', 'k_{max}');
hold off;
title('Inner PID Controller Output (Raw k)');
xlabel('Time (s)');
ylabel('Raw k value');
legend('show', 'Location', 'best');
grid on;
xlim([0 tSim]);

sgtitle(['Batch Reactor Detailed Simulation (T_{ref} = ' num2str(T_ref) '°C)'], 'FontSize', 14, 'FontWeight', 'bold');

disp('--- Script Finished ---');
