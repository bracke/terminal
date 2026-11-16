with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Text_IO;

package body Terminal.App.Session_Profile_Discovery is
   Max_Line_Length : constant := 2_048;

   function Profile_Name (Host : String) return String is
      Result : String (1 .. Terminal.App.Session_Profiles.Max_Name_Length);
      Last : Natural := 0;
      procedure Append (Ch : Character) is
      begin
         if Last < Result'Last then
            Last := Last + 1;
            Result (Last) := Ch;
         end if;
      end Append;
   begin
      for Ch of String'("ssh-") loop Append (Ch); end loop;
      for Ch of Host loop
         if Ch in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' then
            Append (Ada.Characters.Handling.To_Lower (Ch));
         else
            Append ('-');
         end if;
      end loop;
      return (if Last = 0 then "" else Result (1 .. Last));
   end Profile_Name;

   procedure Discover_SSH
     (Profiles : in out Terminal.App.Session_Profiles.Registry;
      Path     : String;
      Added    : out Natural)
   is
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. Max_Line_Length);
      Last : Natural;
      Overflow : Boolean;

      procedure Read_Line is
         Ch : Character;
      begin
         Last := 0;
         Overflow := False;
         while not Ada.Text_IO.End_Of_Line (File) loop
            Ada.Text_IO.Get (File, Ch);
            if Last < Line'Last then
               Last := Last + 1;
               Line (Last) := Ch;
            else
               Overflow := True;
            end if;
         end loop;
         if not Ada.Text_IO.End_Of_File (File) then Ada.Text_IO.Skip_Line (File); end if;
      end Read_Line;

      procedure Add_Host (Host : String) is
         Name : constant String := Profile_Name (Host);
         Accepted : Boolean;
         Before : constant Natural := Terminal.App.Session_Profiles.Count (Profiles);
      begin
         if Host = "" or else Name = "" then return; end if;
         for Ch of Host loop
            if Ch in '*' | '?' | '!' then return; end if;
         end loop;
         Terminal.App.Session_Profiles.Apply_Field
           (Profiles, Name & ".ssh", Host, Accepted);
         if Accepted
           and then Terminal.App.Session_Profiles.Count (Profiles) > Before
         then
            Added := Added + 1;
         end if;
      end Add_Host;
   begin
      Added := 0;
      if Path = "" or else not Ada.Directories.Exists (Path) then return; end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File)
        and then Terminal.App.Session_Profiles.Count (Profiles) <
          Terminal.App.Session_Profiles.Max_Profiles
      loop
         Read_Line;
         if not Overflow and then Last > 0 then
            declare
               First : Natural := 1;
            begin
               while First <= Last and then Line (First) in ' ' | ASCII.HT loop
                  First := First + 1;
               end loop;
               if First + 4 <= Last
                 and then Ada.Characters.Handling.To_Lower
                   (Line (First .. First + 3)) = "host"
                 and then Line (First + 4) in ' ' | ASCII.HT
               then
                  First := First + 5;
                  while First <= Last loop
                     while First <= Last
                       and then Line (First) in ' ' | ASCII.HT
                     loop
                        First := First + 1;
                     end loop;
                     exit when First > Last;
                     declare
                        Stop : Natural := First;
                     begin
                        while Stop <= Last
                          and then Line (Stop) not in ' ' | ASCII.HT
                        loop
                           Stop := Stop + 1;
                        end loop;
                        Add_Host (Line (First .. Stop - 1));
                        First := Stop + 1;
                     end;
                  end loop;
               end if;
            end;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
   end Discover_SSH;
end Terminal.App.Session_Profile_Discovery;
