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
         if Field not in "command" | "shell" | "cwd" | "environment" | "ssh" | "theme"
           or else (Field = "environment" and then not Valid_Environment (Value))
           or else (Field = "ssh" and then not Valid_Host (Value))
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
         elsif Field = "shell" then
            Set (Profiles.Items (Index).Shell_Path, Value);
            Profiles.Items (Index).Host := (others => <>);
            Profiles.Items (Index).Start := (others => <>);
         elsif Field = "cwd" then
            Set (Profiles.Items (Index).CWD, Value);
         elsif Field = "environment" then
            Set (Profiles.Items (Index).Env, Value);
         elsif Field = "ssh" then
            Set (Profiles.Items (Index).Host, Value);
            Profiles.Items (Index).Start := (others => <>);
            Profiles.Items (Index).Shell_Path := (others => <>);
         elsif Field = "theme" then
            Set (Profiles.Items (Index).Theme, Value);
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
         Append ("exec ssh -- " & Shell_Quote (SSH_Host (Value)));
      elsif Shell (Value) /= "" then
         Append ("exec " & Shell_Quote (Shell (Value)));
      else
         Append (Command (Value));
      end if;
      return (if Overflow or else Last = 0 then "" else Result (1 .. Last));
   end Launch_Command;
end Terminal.App.Session_Profiles;
