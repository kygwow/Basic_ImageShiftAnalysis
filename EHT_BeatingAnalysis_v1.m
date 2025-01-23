%The purpose of this script is visualize and analysis the beating of EHT device
%
%   input:  1. video file(vidObj)
%   output: 1. visulazation of beating (video)
%           2. estimated drift values(mat)
%   
%   Users are able to manually select the Region of interest for drift
%   estimation(e.g. drift is local)
%
%   2021.02.09 Initial version (v1)
%   Yong Guk Kang


clear 

%input parameter
vidObj=VideoReader('*****x4001.mp4');
vidObj.CurrentTime=0;
realFov=[2945,2945];%micron
manualROI=1;


%% calculated parameters
%time index
tindex=1/vidObj.FrameRate:1/vidObj.FrameRate:vidObj.Duration;
%physical scale
pxtoMicron=realFov(1)/vidObj.Height;

%% import data
%video read as stack of images
for fi=1:vidObj.NumFrames
    Data.frames(:,:,fi)=rgb2gray(readFrame(vidObj));
    %calculate image entropy
    Data.ent(fi)=entropy(Data.frames(:,:,fi));
end

%% compute drifted values
%selecte the most crisp image as the reference

templatePos=find(Data.ent==max(Data.ent));

if manualROI==false
    for fi=1:vidObj.NumFrames
        temp=imregcorr(Data.frames(:,:,templatePos),Data.frames(:,:,fi),'translation','Window',true);
        Data.registered(:,:,fi)=imtranslate(Data.frames(:,:,fi),-temp.T(3,1:2),'FillValues',255);
        Data.driftEst(1:2,fi)=temp.T(3,1:2);
    end

else
    figure;imagesc(Data.frames(:,:,templatePos));axis image;    
    title('select ROI')    
    roi=drawrectangle('Color','r');
    roi.Position=round(roi.Position);
    disp(roi.Position);
    
    for fi=1:vidObj.NumFrames
    temp=imregcorr(Data.frames(roi.Position(1):roi.Position(1)+roi.Position(3),roi.Position(2):roi.Position(2)+roi.Position(4),templatePos),Data.frames(roi.Position(1):roi.Position(1)+roi.Position(3),roi.Position(2):roi.Position(2)+roi.Position(4),fi),'translation','Window',true);
    Data.registered(:,:,fi)=imtranslate(Data.frames(:,:,fi),-temp.T(3,1:2),'FillValues',255);
    Data.driftEst(1:2,fi)=temp.T(3,1:2);
    end
    
end

%scale to real physical scale
Data.driftEst=pxtoMicron.*Data.driftEst;

%give offset as make beating on zero-positive range 
Data.driftEst(1,:)=Data.driftEst(1,:)-min(Data.driftEst(1,:));
Data.driftEst(2,:)=Data.driftEst(2,:)-min(Data.driftEst(2,:));

%compute absolute deformation (no directionality)
Data.absEst=sqrt((Data.driftEst(1,:).^2+Data.driftEst(2,:).^2));       

%visualization parameter :set the range of plot
xbox=[min(Data.driftEst(1,:)),max(Data.driftEst(1,:))]+[-0.1*max(Data.driftEst(1,:)) +0.1*max(Data.driftEst(1,:))];
ybox=[min(Data.driftEst(2,:)),max(Data.driftEst(2,:))]+[-0.1*max(Data.driftEst(2,:)) +0.1*max(Data.driftEst(2,:))];
abox=[min(Data.absEst),max(Data.absEst)]+[-0.1*max(Data.absEst) +0.1*max(Data.absEst)];
scatterColor = parula(vidObj.NumFrames);


%% Visualize

%video save initialize
vout=VideoWriter(['output_',sprintf(vidObj.Name),'.avi']);
vout.FrameRate=vidObj.FrameRate;
vout.Quality=95;
open(vout);

%open new figure window
v1=figure;
v1.Position=([434 313 800 600]);
v1.Color='w';

for fi=1:vidObj.NumFrames
    try
        figure(v1)
        subplot(2,2,1)
        imshow(Data.frames(:,:,fi));
        title(sprintf(vidObj.Name),'Interpreter','none');
        xlabel(['Fov(micron) : ',sprintf('%d',realFov(1)),', frame: ',sprintf('%d / %d',fi,vidObj.NumFrames)])

        subplot(2,2,2)
        %for colorful scattering plot
        if fi==1
            line(Data.driftEst(1,1:2),Data.driftEst(2,1:2),'Color',scatterColor(fi,:),'LineWidth',2,'Marker','*');    
            xlabel('X(Micron)');ylabel('Y(Micron)')
            xlim([xbox(1) xbox(2)]);
            ylim([ybox(1) ybox(2)]);
            hold on ; 
        else
            line(Data.driftEst(1,fi-1:fi),Data.driftEst(2,fi-1:fi),'Color',scatterColor(fi,:),'LineWidth',2,'Marker','*');
        end
        
        %absolute value
        subplot(2,2,3:4)
        plot(tindex(1:fi),Data.absEst(1:fi),'Color','k','LineWidth',2)
        title(sprintf('Max absolute displacement:%3.2f microns',max(Data.absEst)))
        xlabel('T');ylabel('Abs(Micron)')
        xlim([tindex(1),tindex(end)])
        ylim([abox(1) abox(2)]);
        pause(1/vidObj.Framerate);
        
        %save current figure as videoframe
        vframe=getframe(gcf);
        writeVideo(vout,vframe);
    catch
        close(vout)
    end
end
close(vout)

%for export purpose
saveVar.name=vidObj.Name;
saveVar.driftEst=Data.driftEst;
save(['data_',sprintf(vidObj.Name),'.mat'],'saveVar');

