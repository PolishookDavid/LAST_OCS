function setCoordinate(MountObj,NewRA,NewDec,MountRA,MountDec,CooSys)
    % Set the mount encoder coordinates to a given values (RA/Dec)
    % Package: +obs/@mount
    % Description: Declare that the current mount position (or an arbitrary position
    %              if more arguments are supplied) has effectively given RA,Dec
    %              coordinates. This is done by shifting .HAZeroPositionTicks and 
    %              .DecZeroPositionTicks of such amounts that the request is fullfilled
    % Input  : - New RA [deg] position, will set the mount RA to this value.
    %          - New Dec [deg] position, will set the mount Dec to this value.
    %          - Mount RA [deg]. If not provided than will read from the
    %            current mount RA. This is always given in Equinox of date.
    %          - Mount Dec [deg]. If not provided than will read from the
    %            current mount Dec. This is always given in Equinox of date.
    %          - Coordinate system of the New RA/Dec: 'J2000' | 'tdate'.
    %            Default is 'J2000'.
    %            Note that the Mount RA/Dec are always in Equinox of date.
    %
    % Usage:
    %
    %  X.setCoordinate(newRA,newDec)  corrects the encoders offsets so that the
    %                                 current mount position is read as (newRA,newDec)
    %                                 All coordinates are in Equinox of Date
    %                                 [deg]
    %
    %  X.setCoordinate(newRA,newDec,RA,Dec)  corrects the encoders offsets so that
    %                                        what is now (RA,Dec) will be pointed
    %                                        to as (newRA,newDec)
    %                                        All coordinates are in Equinox of
    %                                        Date [deg]
    %
    %  Note: in a simplicistic way, this is done simply adding to the encoder zero
    %        positions the differences between old and new coordinates.
    %        Beware!!
    %        Funny things may happen for large corrections, or for corrections
    %        which involve changing flip quadrant (i.e. involving one of the two
    %        sets below the celestial north pole, Dec==180-MotorDec)
    % Examples:
    %       M.setCoordinate(newRA,newDec,mountRA,mountDec)
    %       M.setCoordinate(newRA,newDec)
    %       By : Eran O. Ofek                        Feb 2021
    % Tested   : 12-02-2021/Eran


    % need to read this from the mount object
    %MountConfigFile = 'config.mount_1_1.txt';


    RAD = 180./pi;

    if nargin==6
        % all parameters are supplied by the user
    elseif nargin==5
        CooSys = 'J2000';
    elseif nargin==3
        MountRA  = MountObj.RA;
        MountDec = MountObj.Dec;
        CooSys   = 'J2000';
    elseif nargin==2

        if ischar(NewRA)
            switch lower(NewRA)
                case 'reset'
                    MountRA  = MountObj.RA;
                    MountDec = MountObj.Dec;
                    NewRA    = MountRA;
                    NewDec   = MountDec;
                otherwise
                    error('Unknown string option in second input argument');
            end
        else
            error('Illegal input arguments');
        end
    else
        error('Illegal input arguments');
    end

    if ischar(NewRA)
        NewRA = celestial.coo.convertdms(NewRA,'SH','d');
    end
    if ischar(NewDec)
        NewDec = celestial.coo.convertdms(NewDec,'SD','d');
    end

    % convert coordinate systems
    switch lower(CooSys)
        case {'tdate','jdate','jnow'}
            % do nothing
            % NewRA, NewDec are already in Equinox of date
        case {'j2000.0','j2000'}
            % NewRA, NewDec are given in J2000
            % convert [NewRA,NewDec] to Jnow
            JD = celestial.time.julday; % JD, UTC now
            JnowStr = sprintf('j%8.3f',convert.time(JD,'JD','J'));
            NewCoo  = celestial.coo.coco([NewRA,NewDec]./RAD,'j2000.0',JnowStr);
            NewRA   = NewCoo(1).*RAD;
            NewDec  = NewCoo(2).*RAD;
        otherwise
            error('Unknown CooSys option');
    end

    % update the encoders position
    %MountObj.Handle.setCoordinate(NewRA,NewDec,MountRA,MountDec);

    switch lower(MountObj.MountType)
        case 'ioptron'
            % not supported
            error('setCoordinate is not supported for iOptron mount');

        case 'xerxes'

            haOffset=(mod(NewRA-MountRA+180,360)-180)*MountObj.Handle.EncoderTicksPerDegree;
            % for Dec, we do not bother wrapping around, modulo, etc., because
            %  doing so would imply handling flip
            decOffset=(NewDec-MountDec)*MountObj.Handle.EncoderTicksPerDegree;


            % read current mount config file
            [ConfigLogical,ConfigPhysical,~,~] = readConfig(MountObj,[MountObj.NodeNumber, MountObj.MountNumber]);

            % write offsets in object
            % RA sign is +1 (in test mount)
            % Dec sign is -1 (in test mount)
            HAZeroPositionTicks    = MountObj.Handle.HAZeroPositionTicks  + ConfigPhysical.RA_encoder_direction .*haOffset;
            DecZeroPositionTicks   = MountObj.Handle.DecZeroPositionTicks + ConfigPhysical.Dec_encoder_direction.*decOffset;
            MountObj.Handle.HAZeroPositionTicks  = HAZeroPositionTicks;
            MountObj.Handle.DecZeroPositionTicks = DecZeroPositionTicks;

            % update offsets in config file
            %configfile.replace_config(ConfigFile,'HAZeroPositionTicks',sprintf('%9d',HAZeroPositionTicks),'ticks');
            %configfile.replace_config(ConfigFile,'DecZeroPositionTicks',sprintf('%9d',DecZeroPositionTicks),'ticks');
            MountObj.updateConfiguration(MountObj.Config,'HAZeroPositionTicks',sprintf('%9d',HAZeroPositionTicks),'ticks');
            MountObj.updateConfiguration(MountObj.Config,'DecZeroPositionTicks',sprintf('%9d',DecZeroPositionTicks),'ticks');

        otherwise
            error('Unknown MountType option');
    end

end
