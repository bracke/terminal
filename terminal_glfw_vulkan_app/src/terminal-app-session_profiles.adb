with Ada.Characters.Handling;
with Ada.Strings.Fixed;

package body Terminal.App.Session_Profiles is
   function Text (Value : Text_Value) return String is
     (if Value.Length = 0 then "" else Value.Text (1 .. Value.Length));

   procedure Set (Target : out Text_Value; Value : String) is
   begin
      Target := (others => <>);
      Target.Length := Value'Length;
      if Value'Length > 0 then
         Target.Text (1 .. Value'Length) := Value;
      end if;
   end Set;

   function Valid_Name (Value : String) return Boolean is
   begin
      if Value'Length not in 1 .. Max_Name_Length then return False; end if;
      for Ch of Value loop
         if Ch not in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' then
            return False;
         end if;
      end loop;
      return True;
   end Valid_Name;

   function Safe_Text (Value : String) return Boolean is
   begin
      if Value'Length > Max_Value_Length then return False; end if;
      for Ch of Value loop
         if Ch in ASCII.NUL .. ASCII.US or else Ch = ASCII.DEL then
            return False;
         end if;
      end loop;
      return True;
   end Safe_Text;

   function Valid_Host (Value : String) return Boolean is
   begin
      if Value = "" then return True; end if;
      for Ch of Value loop
         if Ch not in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9'
           | '.' | '-' | '_' | '@' | ':' | '[' | ']'
         then
            return False;
         end if;
      end loop;
      return True;
   end Valid_Host;

   function Valid_Baud (Value : String) return Boolean is
      Number : Natural;
   begin
      if Value = "" then return True; end if;
      for Ch of Value loop
         if Ch not in '0' .. '9' then return False; end if;
      end loop;
      Number := Natural'Value (Value);
      return Number in 50 .. 4_000_000;
   exception
      when Constraint_Error => return False;
   end Valid_Baud;

   function Valid_Port (Value : String) return Boolean is
      Number : Natural;
   begin
      if Value = "" then return True; end if;
      for Ch of Value loop
         if Ch not in '0' .. '9' then return False; end if;
      end loop;
      Number := Natural'Value (Value);
      return Number in 1 .. 65_535;
   exception
      when Constraint_Error => return False;
   end Valid_Port;

   function Parse_Boolean (Value : String; Result : out Boolean) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Value);
   begin
      if Lower in "true" | "yes" | "on" | "1" then
         Result := True;
         return True;
      elsif Lower in "false" | "no" | "off" | "0" | "" then
         Result := False;
         return True;
      end if;
      Result := False;
      return False;
   end Parse_Boolean;

   function Valid_Environment (Value : String) return Boolean is
      Start : Natural := Value'First;
      Stop : Natural;
      Equal : Natural;
   begin
      if Value = "" then return True; end if;
      if Value (Value'Last) = ',' then return False; end if;
      while Start <= Value'Last loop
         Stop := Ada.Strings.Fixed.Index (Value, ",", From => Start);
         if Stop = 0 then Stop := Value'Last + 1; end if;
         Equal := Ada.Strings.Fixed.Index
           (Value (Start .. Stop - 1), "=");
         if Equal = 0 or else Equal = Start then return False; end if;
         for I in Start .. Equal - 1 loop
            if (I = Start and then Value (I) not in 'a' .. 'z' | 'A' .. 'Z' | '_')
              or else
                (I > Start and then Value (I) not in
                   'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_')
            then
               return False;
            end if;
         end loop;
         Start := Stop + 1;
      end loop;
      return Safe_Text (Value);
   exception
      when Constraint_Error => return False;
   end Valid_Environment;

   function Find (Profiles : Registry; Name : String) return Natural is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      for I in 1 .. Profiles.Length loop
         if Ada.Characters.Handling.To_Lower
           (Text (Profiles.Items (I).Profile_Name)) = Lower
         then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Apply_Field
     (Profiles : in out Registry;
      Key      : String;
      Value    : String;
      Accepted : out Boolean)
   is
      Dot : constant Natural := Ada.Strings.Fixed.Index (Key, ".");
      Index : Natural;
      Theme : Terminal.App.Theme.Theme_Name;
   begin
      Accepted := False;
      if Dot = 0 or else Dot = Key'First or else Dot = Key'Last then return; end if;
      declare
         Profile_Name : constant String := Key (Key'First .. Dot - 1);
         Field : constant String :=
           Ada.Characters.Handling.To_Lower (Key (Dot + 1 .. Key'Last));
      begin
         if not Valid_Name (Profile_Name) or else not Safe_Text (Value) then
            return;
         end if;
         if Field not in "command" | "shell" | "cwd" | "environment" | "ssh"
           | "serial" | "baud" | "socket" | "container" | "wsl" | "tls"
           | "theme" | "persistent" | "ssh-identity" | "ssh-port"
           | "ssh-jump" | "ssh-setup"
           or else (Field = "environment" and then not Valid_Environment (Value))
           or else (Field = "ssh" and then not Valid_Host (Value))
           or else (Field = "tls" and then not Valid_Host (Value))
           or else (Field = "baud" and then not Valid_Baud (Value))
           or else (Field = "ssh-port" and then not Valid_Port (Value))
           or else (Field = "theme" and then Value /= ""
             and then not Terminal.App.Theme.Parse_Name (Value, Theme))
         then
            return;
         end if;
         Index := Find (Profiles, Profile_Name);
         if Index = 0 then
            if Profiles.Length = Max_Profiles then return; end if;
            Profiles.Length := Profiles.Length + 1;
            Index := Profiles.Length;
            Set (Profiles.Items (Index).Profile_Name, Profile_Name);
         end if;
         if Field = "command" then
            Set (Profiles.Items (Index).Start, Value);
            Profiles.Items (Index).Host := (others => <>);
            Profiles.Items (Index).Shell_Path := (others => <>);
            Profiles.Items (Index).Serial := (others => <>);
            Profiles.Items (Index).Socket := (others => <>);
            Profiles.Items (Index).Container := (others => <>);
            Profiles.Items (Index).WSL := (others => <>);
            Profiles.Items (Index).TLS := (others => <>);
         elsif Field = "shell" then
            Set (Profiles.Items (Index).Shell_Path, Value);
            Profiles.Items (Index).Host := (others => <>);
            Profiles.Items (Index).Start := (others => <>);
            Profiles.Items (Index).Serial := (others => <>);
            Profiles.Items (Index).Socket := (others => <>);
            Profiles.Items (Index).Container := (others => <>);
            Profiles.Items (Index).WSL := (others => <>);
            Profiles.Items (Index).TLS := (others => <>);
         elsif Field = "cwd" then
            Set (Profiles.Items (Index).CWD, Value);
         elsif Field = "environment" then
            Set (Profiles.Items (Index).Env, Value);
         elsif Field = "ssh" then
            Set (Profiles.Items (Index).Host, Value);
            Profiles.Items (Index).Start := (others => <>);
            Profiles.Items (Index).Shell_Path := (others => <>);
            Profiles.Items (Index).Serial := (others => <>);
            Profiles.Items (Index).Socket := (others => <>);
            Profiles.Items (Index).Container := (others => <>);
            Profiles.Items (Index).WSL := (others => <>);
            Profiles.Items (Index).TLS := (others => <>);
         elsif Field = "serial" then
            Set (Profiles.Items (Index).Serial, Value);
            Profiles.Items (Index).Host := (others => <>);
            Profiles.Items (Index).Start := (others => <>);
            Profiles.Items (Index).Shell_Path := (others => <>);
            Profiles.Items (Index).Socket := (others => <>);
            Profiles.Items (Index).Container := (others => <>);
            Profiles.Items (Index).WSL := (others => <>);
            Profiles.Items (Index).TLS := (others => <>);
         elsif Field = "baud" then
            Set (Profiles.Items (Index).Baud, Value);
         elsif Field = "socket" then
            Set (Profiles.Items (Index).Socket, Value);
            Profiles.Items (Index).Host := (others => <>);
            Profiles.Items (Index).Start := (others => <>);
            Profiles.Items (Index).Shell_Path := (others => <>);
            Profiles.Items (Index).Serial := (others => <>);
            Profiles.Items (Index).Container := (others => <>);
            Profiles.Items (Index).WSL := (others => <>);
            Profiles.Items (Index).TLS := (others => <>);
         elsif Field = "container" then
            Set (Profiles.Items (Index).Container, Value);
            Profiles.Items (Index).Host := (others => <>);
            Profiles.Items (Index).Start := (others => <>);
            Profiles.Items (Index).Shell_Path := (others => <>);
            Profiles.Items (Index).Serial := (others => <>);
            Profiles.Items (Index).Socket := (others => <>);
            Profiles.Items (Index).WSL := (others => <>);
            Profiles.Items (Index).TLS := (others => <>);
         elsif Field = "wsl" then
            Set (Profiles.Items (Index).WSL, Value);
            Profiles.Items (Index).Host := (others => <>);
            Profiles.Items (Index).Start := (others => <>);
            Profiles.Items (Index).Shell_Path := (others => <>);
            Profiles.Items (Index).Serial := (others => <>);
            Profiles.Items (Index).Socket := (others => <>);
            Profiles.Items (Index).Container := (others => <>);
            Profiles.Items (Index).TLS := (others => <>);
         elsif Field = "tls" then
            Set (Profiles.Items (Index).TLS, Value);
            Profiles.Items (Index).Host := (others => <>);
            Profiles.Items (Index).Start := (others => <>);
            Profiles.Items (Index).Shell_Path := (others => <>);
            Profiles.Items (Index).Serial := (others => <>);
            Profiles.Items (Index).Socket := (others => <>);
            Profiles.Items (Index).Container := (others => <>);
            Profiles.Items (Index).WSL := (others => <>);
         elsif Field = "theme" then
            Set (Profiles.Items (Index).Theme, Value);
         elsif Field = "ssh-identity" then
            Set (Profiles.Items (Index).Identity, Value);
         elsif Field = "ssh-port" then
            Set (Profiles.Items (Index).Port, Value);
         elsif Field = "ssh-jump" then
            if not Valid_Host (Value) then return; end if;
            Set (Profiles.Items (Index).Jump_Host, Value);
         elsif Field = "ssh-setup" then
            if not Parse_Boolean
              (Value, Profiles.Items (Index).Remote_Setup)
            then
               return;
            end if;
         elsif Field = "persistent" then
            if not Parse_Boolean (Value, Profiles.Items (Index).Keep_Alive) then
               return;
            end if;
         else
            return;
         end if;
         Accepted := True;
      end;
   end Apply_Field;

   procedure Set_Default
     (Profiles : in out Registry;
      Name     : String;
      Accepted : out Boolean) is
   begin
      Accepted := Name = "" or else Valid_Name (Name);
      if Accepted then Set (Profiles.Default_Name, Name); end if;
   end Set_Default;

   function Count (Profiles : Registry) return Natural is (Profiles.Length);

   function Item (Profiles : Registry; Index : Positive) return Profile is
   begin
      if Index > Profiles.Length then raise Constraint_Error; end if;
      return Profiles.Items (Index);
   end Item;

   function Default_Index (Profiles : Registry) return Natural is
     (if Profiles.Default_Name.Length = 0 then 0
      else Find (Profiles, Text (Profiles.Default_Name)));

   function Name (Value : Profile) return String is (Text (Value.Profile_Name));
   function Working_Directory (Value : Profile) return String is (Text (Value.CWD));
   function Command (Value : Profile) return String is (Text (Value.Start));
   function Shell (Value : Profile) return String is (Text (Value.Shell_Path));
   function Environment (Value : Profile) return String is (Text (Value.Env));
   function SSH_Host (Value : Profile) return String is (Text (Value.Host));
   function SSH_Identity (Value : Profile) return String is
     (Text (Value.Identity));
   function SSH_Port (Value : Profile) return String is (Text (Value.Port));
   function SSH_Jump_Host (Value : Profile) return String is
     (Text (Value.Jump_Host));
   function SSH_Remote_Setup (Value : Profile) return Boolean is
     (Value.Remote_Setup);
   function Persistent (Value : Profile) return Boolean is (Value.Keep_Alive);
   function Serial_Device (Value : Profile) return String is (Text (Value.Serial));
   function Serial_Baud (Value : Profile) return String is (Text (Value.Baud));
   function Socket_Path (Value : Profile) return String is (Text (Value.Socket));
   function Container_Name (Value : Profile) return String is
     (Text (Value.Container));
   function WSL_Distribution (Value : Profile) return String is (Text (Value.WSL));
   function TLS_Host (Value : Profile) return String is (Text (Value.TLS));
   function Theme_Name (Value : Profile) return String is (Text (Value.Theme));

   function Shell_Quote (Value : String) return String is
      Result : String (1 .. Value'Length * 5 + 2);
      Last : Natural := 1;
   begin
      Result (1) := ''';
      for Ch of Value loop
         if Ch = ''' then
            Result (Last + 1 .. Last + 5) := "'""'""'";
            Last := Last + 5;
         else
            Last := Last + 1;
            Result (Last) := Ch;
         end if;
      end loop;
      Last := Last + 1;
      Result (Last) := ''';
      return Result (1 .. Last);
   end Shell_Quote;

   function Launch_Command (Value : Profile) return String is
      Result : String (1 .. Max_Launch_Command_Length);
      Last : Natural := 0;
      Overflow : Boolean := False;
      procedure Append (Part : String) is
      begin
         for Ch of Part loop
            if Last = Result'Last then
               Overflow := True;
               return;
            else
               Last := Last + 1;
               Result (Last) := Ch;
            end if;
         end loop;
      end Append;
      Env : constant String := Environment (Value);
      Start : Natural := Env'First;
      Stop : Natural;
      Equal : Natural;
      procedure Append_SSH_Options is
      begin
         Append
           ("-o ControlMaster=auto -o ControlPersist=600 "
            & "-o ServerAliveInterval=30 -o ServerAliveCountMax=3 ");
         if SSH_Identity (Value) /= "" then
            Append ("-i " & Shell_Quote (SSH_Identity (Value)) & " ");
         end if;
         if SSH_Port (Value) /= "" then
            Append ("-p " & SSH_Port (Value) & " ");
         end if;
         if SSH_Jump_Host (Value) /= "" then
            Append ("-J " & Shell_Quote (SSH_Jump_Host (Value)) & " ");
         end if;
      end Append_SSH_Options;
   begin
      if Env /= "" then
         Append ("export ");
         while Start <= Env'Last loop
            Stop := Ada.Strings.Fixed.Index (Env, ",", From => Start);
            if Stop = 0 then Stop := Env'Last + 1; end if;
            Equal := Ada.Strings.Fixed.Index (Env (Start .. Stop - 1), "=");
            Append (Env (Start .. Equal));
            Append (Shell_Quote (Env (Equal + 1 .. Stop - 1)));
            if Stop <= Env'Last then Append (" "); end if;
            Start := Stop + 1;
         end loop;
         Append ("; ");
      end if;
      if SSH_Host (Value) /= "" then
         Append ("TERM=xterm-256color exec ssh ");
         Append_SSH_Options;
         if SSH_Remote_Setup (Value) then Append ("-t "); end if;
         Append ("-- " & Shell_Quote (SSH_Host (Value)));
         if SSH_Remote_Setup (Value) then
            Append
              (" 'if command -v tic >/dev/null 2>&1; then "
               & "printf %s\n "
               & """bracke-terminal|Bracke Terminal,use=xterm-256color,"" "
               & "| tic -x - >/dev/null 2>&1 && TERM=bracke-terminal; "
               & "fi; export TERM BRACKE_TERMINAL_REMOTE=1; "
               & "exec ""${SHELL:-/bin/sh}"" -l'");
         end if;
      elsif Serial_Device (Value) /= "" then
         Append
           ("exec picocom --baud "
            & (if Serial_Baud (Value) = "" then "115200"
               else Serial_Baud (Value))
            & " -- " & Shell_Quote (Serial_Device (Value)));
      elsif Socket_Path (Value) /= "" then
         Append
           ("exec socat STDIO UNIX-CONNECT:"
            & Shell_Quote (Socket_Path (Value)));
      elsif Container_Name (Value) /= "" then
         Append
           ("exec docker exec -it -- " & Shell_Quote (Container_Name (Value))
            & " /bin/sh");
      elsif WSL_Distribution (Value) /= "" then
         Append
           ("exec wsl.exe -d " & Shell_Quote (WSL_Distribution (Value)));
      elsif TLS_Host (Value) /= "" then
         Append
           ("exec openssl s_client -quiet -connect "
            & Shell_Quote (TLS_Host (Value)));
      elsif Persistent (Value) then
         Append
           ("exec tmux new-session -A -s " & Shell_Quote (Name (Value)));
         if Working_Directory (Value) /= "" then
            Append (" -c " & Shell_Quote (Working_Directory (Value)));
         end if;
         if Shell (Value) /= "" then
            Append (" " & Shell_Quote (Shell (Value)));
         elsif Command (Value) /= "" then
            Append (" " & Shell_Quote (Command (Value)));
         end if;
      elsif Shell (Value) /= "" then
         Append ("exec " & Shell_Quote (Shell (Value)));
      else
         Append (Command (Value));
      end if;
      return (if Overflow or else Last = 0 then "" else Result (1 .. Last));
   end Launch_Command;
end Terminal.App.Session_Profiles;
