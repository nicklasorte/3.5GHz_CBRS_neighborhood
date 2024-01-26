clear;
clc;
close all;
top_start_clock=clock;
app=NaN(1);
folder1='C:\Local Matlab Data\3.5Ghz Neighborhood Github Example';
cd(folder1)
addpath(folder1)
pause(0.1)
addpath('C:\Local Matlab Data\General_Movelist') %%%%%%%%This is another Github repo

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%CBRS Neighborhood Calculation 

%%%%%%%Loading  DPA Geography and 10km Coast Line
load('cell_expand_all_dpa.mat','cell_expand_all_dpa')
load('downsampled_east10km.mat','downsampled_east10km')
load('downsampled_west10km.mat','downsampled_west10km')
load('us_cont.mat','us_cont')


%%%%%%%%%%%%%%%%%%%%%% Real
tic;
'Loading Randomized Real . . .'
load('cell_err_data_single_sector.mat','cell_err_data_single_sector')
cell_bs_data=cell_err_data_single_sector;
toc; %%%%%%%2 Seconds

tic;
load('aas_zero_elevation_data.mat','aas_zero_elevation_data')
toc;
%%%%1) Azimuth -180~~180
%%%2) Rural
%%%3) Suburban
%%%4) Urban
%%%%AAS Reduction in Gain to Max Gain (0dB is 0dB reduction, which equates to the make antenna gain of 25dB)
%%%%Need to normalize to zero after the "downtilt reductions" are calculated
%%%%To simplify the data, this is gain at the horizon. 50th Percentile

aas_zero_elevation_data(1,:)
%%%%%%%%%%Set all gains to 0dB, since there will be no azimuths
aas_zero_elevation_data(:,[2:4])=0;
bs_down_tilt_reduction=abs(max(aas_zero_elevation_data(:,[2:4]))); %%%%%%%%Downtilt dB Value for Rural/Suburban/Urban
norm_aas_zero_elevation_data=horzcat(aas_zero_elevation_data(:,1),aas_zero_elevation_data(:,[2:4])+bs_down_tilt_reduction);
max(norm_aas_zero_elevation_data(:,[2:4])) %%%%%This should be [0 0 0]



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Make a Simulation Folder
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rev=101; %%%%%%Example of East 2 with Randomized Real and Cat Z
freq_separation=0; %%%%%%%Assuming co-channel
array_bs_eirp=horzcat(65,62,62); %%%%%EIRP [dBm/10MHz] for Rural, Suburan, Urban 
network_loading_reduction=8  

tf_opt=0;
maine_exception=1;  %%%%%%Just leave this to 1
tf_full_binary_search=1;  %%%%%Search all DPA Points, not just the max distance point
min_binaray_spacing=4; %%%%%%%minimum search distance (km)
margin=1; %%%1dB  margin for aggregate interference
reliability=[1,2,3,4,5,6,7,8,9,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,91,92,93,94,95,96,97,98,99]'; %%%A custom ITM range to interpolate from
move_list_reliability=reliability;
agg_check_reliability=reliability;
min_azimuth=0; %%%%%%Of the Radar
max_azimuth=360; %%%%%%%Of the radar
building_loss=15;  %%%%%%%%%Not used in the CatC
Tpol=1; %%%polarization for ITM
FreqMHz=3550;
confidence=50;
mc_percentile=95; %%%%95th Percentile (if 50% ITM, set mc_percentile=100 and mc_size=1)
mc_size=1000; %%%%%Number of Monte Carlo Iterations (WinnForum 2000)
deployment_percentage=100;
sim_radius_km=1024; %%%%%%%%Placeholder distance         binary_dist_array=[2,4,8,16,32,64,128,256,512,1024,2048];
tf_census=0; %%%%%%%If 0, then us randomized real.
base_station_height=NaN(1,1); %%%%If NaN, then keep the normal heights
tf_cbsd_mask=1;
tf_clutter=0;%1;  %%%%%%%????, Just do this in the EIRP reductions
num_pts=8;  %%%%%%%Number of DPA Sample Points along the front edge, 8 keeps the computational time down
number_rand_pts=NaN(1);
min_ant_loss=40; %%%%%%%%Main to side gain: 40dB
dpa_idx=find(matches(cell_expand_all_dpa(:,1),'East 2'))
array_bs_eirp_reductions=(array_bs_eirp-network_loading_reduction) %%%%%Rural, Suburban, Urban cols:(1-3), No Mitigations/Mitigations rows:(1-2)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%













%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%1)Name, 2)Lat/Lon, 3) Radar Threshold, 4) Radar Height, 5)Radar Beamwidth, 6)tf_ship (for protection points)
cell_dpa_geo=vertcat(cell_expand_all_dpa([dpa_idx],[1,3])); %%%%%Selecting the DPAs to calculate the Neighborhood: Name/Geo Points
cell_threshold=cell(1,1);
cell_threshold{1}=-144; %%%%%-144dBm/10Mhz
cell_dpa_geo(:,3)=cell_threshold;
cell_temp_height=cell(1,1);
cell_temp_height{1}=50;
cell_dpa_geo(:,4)=cell_temp_height;
cell_temp_bw=cell(1,1);
cell_temp_bw{1}=3;  %%%%%3 degrees, Horizontal Beamwidth
cell_dpa_geo(:,5)=cell_temp_bw;
cell_tf_ship1=cell(1,1);
cell_tf_ship1{1}=1;
cell_tf_ship0=cell(1,1);
cell_tf_ship0{1}=0;


for i=1:1:length(dpa_idx)
    if contains(cell_dpa_geo(i,1),'East') || contains(cell_dpa_geo(i,1),'West')
        cell_dpa_geo(i,6)=cell_tf_ship1; 
    else
         cell_dpa_geo(i,6)=cell_tf_ship0; 
    end

    if contains(cell_dpa_geo(i,1),'PascagoulaPort') ||  contains(cell_dpa_geo(i,1),'WebsterField') ||  contains(cell_dpa_geo(i,1),'Pensacola') ||  contains(cell_dpa_geo(i,1),'Alameda') ||  contains(cell_dpa_geo(i,1),'LongBeach') 
        cell_dpa_geo{i,3}=-139;
    end
end

cell_dpa_geo



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%Create a Rev Folder
cd(folder1);
pause(0.1)
tempfolder=strcat('Rev',num2str(rev));
[status,msg,msgID]=mkdir(tempfolder);
rev_folder=fullfile(folder1,tempfolder);
cd(rev_folder)
pause(0.1)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Saving the simulation files in a folder for the option to run from a server
save('cell_dpa_geo.mat','cell_dpa_geo')
save('reliability.mat','reliability')
save('move_list_reliability.mat','move_list_reliability')
save('confidence.mat','confidence')
save('FreqMHz.mat','FreqMHz')
save('Tpol.mat','Tpol')
save('building_loss.mat','building_loss')
save('tf_opt.mat','tf_opt')
save('mc_percentile.mat','mc_percentile')
save('mc_size.mat','mc_size')
save('margin.mat','margin')
save('deployment_percentage.mat','deployment_percentage')
save('tf_full_binary_search.mat','tf_full_binary_search')
save('min_binaray_spacing.mat','min_binaray_spacing')
save('building_loss.mat','building_loss')
save('sim_radius_km.mat','sim_radius_km')
save('array_bs_eirp_reductions.mat','array_bs_eirp_reductions') %%%%%Rural, Suburban, Urban cols:(1-3), No Mitigations/Mitigations rows:(1-2)
save('agg_check_reliability.mat','agg_check_reliability')
save('norm_aas_zero_elevation_data.mat','norm_aas_zero_elevation_data')
save('maine_exception.mat','maine_exception')

%%%%%%%%%%%%%
[num_loc,~]=size(cell_dpa_geo);
location_table=table([1:1:num_loc]',cell_dpa_geo(:,1))
array_bs_latlon=cell2mat(cell_bs_data(:,[5,6]));
size(array_bs_latlon)

for base_idx=1:1:num_loc
    strcat(num2str(base_idx/num_loc*100),'%')
    
    temp_cell_geo_data=cell_dpa_geo(base_idx,:)
    data_label1=erase(temp_cell_geo_data{1}," ");  %%%Remove the Spaces
    
    %%%%%%%%%Step 1: Make a Folder for this single DPA
    cd(rev_folder);
    pause(0.1)
    tempfolder2=strcat(data_label1);
    [status,msg,msgID]=mkdir(tempfolder2);
    sim_folder=fullfile(rev_folder,tempfolder2);
    cd(sim_folder)
    pause(0.1)
    
    
    base_polygon=temp_cell_geo_data{2};  %%%%%%DPA or Base
    save(strcat(data_label1,'_base_polygon.mat'),'base_polygon')
    
    tf_ship=temp_cell_geo_data{6};
    if tf_ship==1
        %%%%Find the inner edge
        uni_base_polygon=unique(base_polygon,'stable','rows');
        inner_edge=vertcat(downsampled_east10km,downsampled_west10km);
        [inner_line,inner_corner1,inner_corner2]=find_dpa_line_overlap(inner_edge,uni_base_polygon);
        base_protection_pts=curvspace(inner_line,num_pts);
    else
        [num_ppts,~]=size(base_polygon);
        if num_ppts==1
            %Do nothing
            base_protection_pts=base_polygon;
        else
            temp_pts=curvspace(base_polygon,num_pts+1);
            base_protection_pts=temp_pts([1:num_pts],:);
            figure;
            hold on;
            plot(base_polygon(:,2),base_polygon(:,1),'-k')
            plot(base_protection_pts(:,2),base_protection_pts(:,1),'or','LineWidth',2)
        end
    end
    
    
    %%%%%%%%%%%%%%%%%%Create pp_pts
    [num_ppts,~]=size(base_polygon);
    if num_ppts==1
        %Do nothing
    else
        if ~isnan(number_rand_pts)==1
            %%%%%Uniform Random Points
            %%%%%%DPA Bounds
            x_max=max(base_polygon(:,2));
            x_min=min(base_polygon(:,2));
            y_max=max(base_polygon(:,1));
            y_min=min(base_polygon(:,1));
            
            rng(rev);%For Repeatability
            %%%Preallocate
            marker1=1;
            rand_pts_uni=NaN(number_rand_pts,2);
            while (marker1<=number_rand_pts)
                %%%Generate Random Points inside DPA
                x_rand=rand(1);
                y_rand=rand(1);
                
                x_pt=x_rand*(x_max-x_min)+x_min;
                y_pt=y_rand*(y_max-y_min)+y_min;
                
                %%%%Check to see if it falls inside the DPA
                tf1=inpolygon(x_pt,y_pt,base_polygon(:,2),base_polygon(:,1));
                
                if tf1==1
                    rand_pts_uni(marker1,:)=horzcat(y_pt,x_pt);
                    marker1=marker1+1;
                    
                end
            end
            
            close all;
            figure;
            hold on;
            scatter(rand_pts_uni(:,2),rand_pts_uni(:,1),10,'or')
            scatter(base_protection_pts(:,2),base_protection_pts(:,1),10,'db')
            plot(base_polygon(:,2),base_polygon(:,1),'-k','LineWidth',2)
            grid on;
            base_protection_pts=vertcat(base_protection_pts,rand_pts_uni);
            size(base_protection_pts)
            pause(0.1)
        end
    end
    save(strcat(data_label1,'_base_protection_pts.mat'),'base_protection_pts') %%%%%Save the Protection Points
    
    
    radar_threshold=temp_cell_geo_data{3};
    radar_height=temp_cell_geo_data{4};
    radar_beamwidth=temp_cell_geo_data{5};

    save(strcat(data_label1,'_radar_threshold.mat'),'radar_threshold')
    save(strcat(data_label1,'_radar_height.mat'),'radar_height')
    save(strcat(data_label1,'_radar_beamwidth.mat'),'radar_beamwidth')
    save(strcat(data_label1,'_min_ant_loss.mat'),'min_ant_loss')
    save(strcat(data_label1,'_min_azimuth.mat'),'min_azimuth')
    save(strcat(data_label1,'_max_azimuth.mat'),'max_azimuth')


    figure;
    hold on;
    plot(base_polygon(:,2),base_polygon(:,1),'-r')
    plot(base_protection_pts(:,2),base_protection_pts(:,1),'ok')
    grid on;
    size(base_protection_pts)
    plot_google_map('maptype','terrain','APIKey','AIzaSyCgnWnM3NMYbWe7N4svoOXE7B2jwIv28F8') %%%Google's API key made by nick.matlab.error@gmail.com
    filename1=strcat('Operational_Area_',data_label1,'.png');
    pause(0.1)
    saveas(gcf,char(filename1))


    %%%%%%%%Sim Bound
    if any(isnan(base_polygon))
        base_polygon=base_polygon(~isnan(base_polygon(:,1)),:);

        figure;
        plot(base_polygon(:,2),base_polygon(:,1),'-r')
    end
    [sim_bound]=calc_sim_bound(app,base_polygon,sim_radius_km,data_label1);

    %%%%%%%Filter Base Stations that are within sim_bound
    tic;
    bs_inside_idx=find(inpolygon(array_bs_latlon(:,2),array_bs_latlon(:,1),sim_bound(:,2),sim_bound(:,1))); %Check to see if the points are in the polygon
    toc;
    size(bs_inside_idx)
    temp_sim_cell_bs_data=cell_bs_data(bs_inside_idx,:);


    %%%%%%%%%%%%Downsample deployment
    [num_inside,~]=size(bs_inside_idx)
    sample_num=ceil(num_inside*deployment_percentage/100)
    rng(rev+base_idx); %%%%%%%For Repeatibility
    rand_sample_idx=datasample(1:num_inside,sample_num,'Replace',false);
    size(temp_sim_cell_bs_data)
    temp_sim_cell_bs_data=temp_sim_cell_bs_data(rand_sample_idx,:);
    size(temp_sim_cell_bs_data)
    temp_lat_lon=cell2mat(temp_sim_cell_bs_data(:,[5,6]));


    figure;
    hold on;
    plot(temp_lat_lon(:,2),temp_lat_lon(:,1),'ob')
    plot(sim_bound(:,2),sim_bound(:,1),'-r','LineWidth',3)
    plot(base_protection_pts(:,2),base_protection_pts(:,1),'sr','Linewidth',4)
    grid on;
    plot_google_map('maptype','terrain','APIKey','AIzaSyCgnWnM3NMYbWe7N4svoOXE7B2jwIv28F8') %%%Google's API key made by nick.matlab.error@gmail.com
    filename1=strcat('Sim_Area_Deployment_',data_label1,'.png');
    pause(0.1)
    saveas(gcf,char(filename1))

    %%%%%%%%%%Add an index for R/S/U (NLCD)
    rural_idx=find(contains(temp_sim_cell_bs_data(:,11),'R'));
    sub_idx=find(contains(temp_sim_cell_bs_data(:,11),'S'));
    urban_idx=find(contains(temp_sim_cell_bs_data(:,11),'U'));
    [num_bs,num_col]=size(temp_sim_cell_bs_data);
    array_ncld_idx=NaN(num_bs,1);
    array_ncld_idx(rural_idx)=1;
    array_ncld_idx(sub_idx)=2;
    array_ncld_idx(urban_idx)=3;
    cell_ncld=num2cell(array_ncld_idx);

    
    %%%%%%%%%%%%%%%%Calculate the clutter and assign the adjusted EIRP for each base station.
    %%%%array_bs_eirp_reductions  %%%%%%1)Rural, 2)Sub, 3)Urban
    clutter_dB=zeros(num_bs,1);
    if tf_clutter==1
        %%%%%%%%%Calculate p452
        [clutter_table]=calculate_p452_clutter_rev1(app,FreqMHz);
        %%%%%NLCD Type 1) Rural, 2)Suburban, 3) Urban, 4) Dense Urban, 5) Antenna Height [m]

        %%%%%%%%%%%%%%%Now find the associated clutter with each Transmitter
        array_ant_height=cell2mat(temp_sim_cell_bs_data(:,10));   %%%10) SE_AntennaHeight_m
        clutter_height_idx=nearestpoint_app(app,array_ant_height,clutter_table(:,5));
        for i=1:1:num_bs
            temp_nlcd_idx=array_ncld_idx(i);
            temp_height_idx=clutter_height_idx(i);
            clutter_dB(i)=clutter_table(temp_height_idx,temp_nlcd_idx);
        end
        unique(clutter_dB)
    else
        %%%%%%No clutter (clutter_dB is already zero)
    end

    array_eirp_bs=NaN(num_bs,2); %%%%%1)No Mitigations, 2)Mitigations --> 14 and 15 of cell
    for i=1:1:num_bs
        temp_nlcd_idx=array_ncld_idx(i);
        array_eirp_bs(i,:)=array_bs_eirp_reductions(:,temp_nlcd_idx)-clutter_dB(i);
    end
    cell_eirp1=num2cell(array_eirp_bs(:,1));
    cell_eirp2=cell_eirp1;
    sim_cell_bs_data=horzcat(temp_sim_cell_bs_data,cell_ncld,cell_eirp1,cell_eirp2);
    size(sim_cell_bs_data)

    sim_cell_bs_data(1,:)

    %%%1) LaydownID
    %%%2) FCCLicenseID
    %%%3) SiteID
    %%%4) SectorID
    %%%5) SiteLatitude_decDeg
    %%%6) SiteLongitude_decDeg
    %%%7) SE_BearingAngle_deg
    %%%8) SE_AntennaAzBeamwidth_deg
    %%%9) SE_DownTilt_deg  %%%%%%%%%%%%%%%%%(Check for Blank)
    %%%10) SE_AntennaHeight_m
    %%%11) SE_Morphology
    %%%12) SE_CatAB
    %%%%%%%%%%13) NLCD idx
    %%%%%%%%%14) EIRP (no mitigations)
    %%%%%%%%%15) EIRP (mitigations)

    tic;
    save(strcat(data_label1,'_sim_cell_bs_data.mat'),'sim_cell_bs_data')
    toc; %%%%%%%%%3 seconds


    %%%%%%%%%%%%%%%Also include the array of the list_catb (order) that we
    %%%%%%%%%%%%%%%usually use for the other sims. (As this will be used
    %%%%%%%%%%%%%%%for the path loss and move list.)

    sim_cell_bs_data(1,:)
    [num_tx,~]=size(sim_cell_bs_data)

    sim_array_list_bs=horzcat(cell2mat(sim_cell_bs_data(:,[5,6,10,14])),NaN(num_tx,1),array_ncld_idx,cell2mat(sim_cell_bs_data(:,[7,15])));
    [num_bs_sectors,~]=size(sim_array_list_bs);
    sim_array_list_bs(:,5)=1:1:num_bs_sectors;
    % % %      %%%%array_list_bs  %%%%%%%1) Lat, 2)Lon, 3)BS height, 4)BS EIRP Adjusted 5) Nick Unique ID for each sector, 6)NLCD: R==1/S==2/U==3, 7) Azimuth 8)BS EIRP Mitigation
    %%%%%%%%If there is no mitigation EIRPs, make all of these NaNs (column 8)

    %%%%%%%%%%%Put the rest of the Link Budget Parameters in this list
    sim_array_list_bs(1,:)
    size(sim_array_list_bs)


    if ~isnan(base_station_height)
        sim_array_list_bs(:,3)=base_station_height;
        'Change all BS height'
        unique(sim_array_list_bs(:,3))
        %pause;
    end
    unique(sim_array_list_bs(:,3))

    tic;
    save(strcat(data_label1,'_sim_array_list_bs.mat'),'sim_array_list_bs')
    toc; %%%%%%%%%3 seconds
        % % %      %%%%array_list_bs  %%%%%%%1) Lat, 2)Lon, 3)BS height, 4)BS EIRP Adjusted 5) Nick Unique ID for each sector, 6)NLCD: R==1/S==2/U==3, 7) Azimuth 8)BS EIRP Mitigation


        'Check for nans in power'
        unique(sim_array_list_bs(:,4))
        any(isnan(sim_array_list_bs(:,4)))
end
cd(rev_folder);
pause(0.1)


end_clock=clock;
total_clock=end_clock-top_start_clock;
total_seconds=total_clock(6)+total_clock(5)*60+total_clock(4)*3600+total_clock(3)*86400;
total_mins=total_seconds/60;
total_hours=total_mins/60;
if total_hours>1
    strcat('Total Hours:',num2str(total_hours))
elseif total_mins>1
    strcat('Total Minutes:',num2str(total_mins))
else
    strcat('Total Seconds:',num2str(total_seconds))
end

'Go run the simulation'






