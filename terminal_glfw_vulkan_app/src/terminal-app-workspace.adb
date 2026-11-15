with Ada.Characters.Handling;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Terminal.App.Workspace is
   procedure Set_Path (Value : out Bounded_Path; Text : String) is
      Count : constant Natural := Natural'Min (Text'Length, Max_Path_Length);
   begin
      Value := (others => <>);
      Value.Length := Count;
      if Count > 0 then
         Value.Text (1 .. Count) := Text (Text'First .. Text'First + Count - 1);
      end if;
   end Set_Path;

   procedure Set_Label (Value : out Bounded_Label; Text : String) is
      Count : constant Natural := Natural'Min (Text'Length, Max_Label_Length);
   begin
      Value := (others => <>);
      Value.Length := Count;
      if Count > 0 then
         Value.Text (1 .. Count) := Text (Text'First .. Text'First + Count - 1);
      end if;
   end Set_Label;

   procedure Set_Command (Value : out Bounded_Command; Text : String) is
      Count : constant Natural := Natural'Min (Text'Length, Max_Command_Length);
   begin
      Value := (others => <>);
      Value.Length := Count;
      if Count > 0 then
         Value.Text (1 .. Count) := Text (Text'First .. Text'First + Count - 1);
      end if;
   end Set_Command;

   function Path_Text (Value : Bounded_Path) return String is
     (if Value.Length = 0 then "" else Value.Text (1 .. Value.Length));

   function Label_Text (Value : Bounded_Label) return String is
     (if Value.Length = 0 then "" else Value.Text (1 .. Value.Length));

   function Command_Text (Value : Bounded_Command) return String is
     (if Value.Length = 0 then "" else Value.Text (1 .. Value.Length));

   function Trimmed (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));

   function Natural_Value (Text : String; Value : out Natural) return Boolean is
   begin
      if Text = "" then
         return False;
      end if;
      for Ch of Text loop
         if Ch not in '0' .. '9' then
            return False;
         end if;
      end loop;
      Value := Natural'Value (Text);
      return True;
   exception
      when Constraint_Error =>
         return False;
   end Natural_Value;

   procedure Load (Path : String; Value : out State; Status : out IO_Status) is
      File : Ada.Text_IO.File_Type;
      Seen_Version : Boolean := False;
      Valid : Boolean := True;
   begin
      Value := (others => <>);
      if Path = "" or else not Ada.Directories.Exists (Path) then
         Status := Not_Found;
         return;
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
            Sep : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
         begin
            if Sep = 0 then
               Valid := False;
            else
               declare
                  Key : constant String :=
                    Ada.Characters.Handling.To_Lower
                      (Trimmed (Line (Line'First .. Sep - 1)));
                  Item : constant String :=
                    (if Sep = Line'Last then ""
                     else Line (Sep + 1 .. Line'Last));
                  Number : Natural;
               begin
                  if Key = "version" then
                     Seen_Version := Trimmed (Item) = "1";
                     Valid := Valid and Seen_Version;
                  elsif Key = "layout" then
                     if Trimmed (Item) = "tabs" then Value.Layout := Tabs;
                     elsif Trimmed (Item) = "panes" then Value.Layout := Panes;
                     elsif Trimmed (Item) = "single" then Value.Layout := Single;
                     else Valid := False;
                     end if;
                  elsif Key = "count" then
                     if Natural_Value (Trimmed (Item), Number)
                       and then Number in 1 .. Terminal.App.Sessions.Max_Sessions
                     then Value.Count := Number;
                     else Valid := False;
                     end if;
                  elsif Key = "active" then
                     if Natural_Value (Trimmed (Item), Number)
                       and then Number in 1 .. Terminal.App.Sessions.Max_Sessions
                     then Value.Active := Number;
                     else Valid := False;
                     end if;
                  elsif Key = "orientation" then
                     if Trimmed (Item) = "horizontal" then
                        Value.Orientation := Horizontal;
                     elsif Trimmed (Item) = "vertical" then
                        Value.Orientation := Vertical;
                     else Valid := False;
                     end if;
                  elsif Key'Length > 8
                    and then Key (Key'First .. Key'First + 7) = "session-"
                  then
                     declare
                        Suffix : constant Natural :=
                          Ada.Strings.Fixed.Index (Key, "-", From => Key'First + 8);
                     begin
                        if Suffix = 0
                          or else not Natural_Value
                            (Key (Key'First + 8 .. Suffix - 1), Number)
                          or else Number not in 1 .. Terminal.App.Sessions.Max_Sessions
                        then
                           Valid := False;
                        elsif Key (Suffix + 1 .. Key'Last) = "cwd" then
                           Set_Path (Value.Entries (Number).Working_Directory, Item);
                        elsif Key (Suffix + 1 .. Key'Last) = "label" then
                           Set_Label (Value.Entries (Number).Label, Item);
                        elsif Key (Suffix + 1 .. Key'Last) = "command" then
                           Set_Command
                             (Value.Entries (Number).Startup_Command, Item);
                        else
                           Valid := False;
                        end if;
                     end;
                  else
                     Valid := False;
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      if not Seen_Version or else Value.Active > Value.Count then
         Valid := False;
      end if;
      Status := (if Valid then Loaded else Invalid_Data);
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         Status := IO_Error;
   end Load;

   procedure Save (Path : String; Value : State; Status : out IO_Status) is
      File : Ada.Text_IO.File_Type;
      Parent : constant String :=
        (if Path = "" then "." else Ada.Directories.Containing_Directory (Path));
      function N (Item : Natural) return String is
        (Ada.Strings.Fixed.Trim (Natural'Image (Item), Ada.Strings.Both));
   begin
      if Path = "" then
         Status := IO_Error;
         return;
      end if;
      if Parent /= "" and then not Ada.Directories.Exists (Parent) then
         Ada.Directories.Create_Path (Parent);
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "version=1");
      Ada.Text_IO.Put_Line
        (File, "layout=" & Ada.Characters.Handling.To_Lower
           (Layout_Kind'Image (Value.Layout)));
      Ada.Text_IO.Put_Line (File, "count=" & N (Value.Count));
      Ada.Text_IO.Put_Line (File, "active=" & N (Value.Active));
      Ada.Text_IO.Put_Line
        (File, "orientation=" & Ada.Characters.Handling.To_Lower
           (Pane_Orientation'Image (Value.Orientation)));
      for I in 1 .. Value.Count loop
         Ada.Text_IO.Put_Line
           (File, "session-" & N (I) & "-cwd="
            & Path_Text (Value.Entries (I).Working_Directory));
         Ada.Text_IO.Put_Line
           (File, "session-" & N (I) & "-label="
            & Label_Text (Value.Entries (I).Label));
         Ada.Text_IO.Put_Line
           (File, "session-" & N (I) & "-command="
            & Command_Text (Value.Entries (I).Startup_Command));
      end loop;
      Ada.Text_IO.Close (File);
      Status := Saved;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         Status := IO_Error;
   end Save;
end Terminal.App.Workspace;
