function Port=construct_port_number(Type,Mount,Camera)
        % Construct a port number for device based on its Type, MountNumber and CameraNumber
        %
        % Port structure XYYZ
        % where X -- is type : Mounts 2, Camera 3, Focusers 4, Sensors
        % 5, Manager 6
        %       YY -- mount number 1..12
        %       Z  -- camera/focuser number 1..4, 1..2 for computer

        % Type Computer DeviceN
        % 2    01       00       - mount on computer 1
        % 3    01       04       - camera 4 on computer 1
        % 3    01       05       - camera 1 listener on computer 1
        % 4    01       04
        % 5    01       01
        % 6    00       00
        % 6    01       00

        if nargin<4
            Computer = [];
        end

        switch lower(Type)
            case 'mount'
                TypeInd = 2;
            case 'camera'
                TypeInd = 3;
            case 'focuser'
                TypeInd = 4;
            case 'sensor'
                TypeInd = 5;
            case 'computer'
                TypeInd = 6;
                % In this case Camera is ComputerNumber
                if mod(Camera,2)==1
                    % odd computer number
                    Camera = 1;
                else
                    Camera = 2;
                end
            case 'manager'
                TypeInd = 7;
            otherwise
                error('Unknown Type option');
        end

        % port number for camera
        Port = 20000 + TypeInd.*1000 + Mount.*10 + Camera;

    end
