with Ada.Characters.Handling;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Terminal.App.Platform_Files;

package body Terminal.App.Workspace is
   use type Terminal.App.Splits.Split_Status;
   Max_Workspace_Line_Length : constant := Max_Path_Length + 64;

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
      Version : Natural := 0;
      Valid : Boolean := True;

      procedure Read_Line
        (Text     : out String;
         Length   : out Natural;
         Overflow : out Boolean)
      is
         Ch : Character;
      begin
         Length := 0;
         Overflow := False;
         while not Ada.Text_IO.End_Of_Line (File) loop
            Ada.Text_IO.Get (File, Ch);
            if Length < Text'Length then
               Length := Length + 1;
               Text (Text'First + Length - 1) := Ch;
            else
               Overflow := True;
            end if;
         end loop;
         if not Ada.Text_IO.End_Of_File (File) then
            Ada.Text_IO.Skip_Line (File);
         end if;
      end Read_Line;
   begin
      Value := (others => <>);
      if Path = "" or else not Ada.Directories.Exists (Path) then
         Status := Not_Found;
         return;
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : String (1 .. Max_Workspace_Line_Length);
            Length : Natural;
            Overflow : Boolean;
         begin
            Read_Line (Line, Length, Overflow);
            if Overflow then
               Valid := False;
            else
               declare
                  Text : constant String := Line (1 .. Length);
                  Sep : constant Natural := Ada.Strings.Fixed.Index (Text, "=");
               begin
                  if Sep = 0 then
                     Valid := False;
                  else
                     declare
                        Key : constant String :=
                          Ada.Characters.Handling.To_Lower
                            (Trimmed (Text (Text'First .. Sep - 1)));
                        Item : constant String :=
                          (if Sep = Text'Last then ""
                           else Text (Sep + 1 .. Text'Last));
                        Number : Natural;
                     begin
                        if Key = "version" then
                           if Natural_Value (Trimmed (Item), Number)
                             and then Number in 1 .. 2
                           then
                              Version := Number;
                              Seen_Version := True;
                           else
                              Seen_Version := False;
                           end if;
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
                        elsif Key = "tree-count" then
                           if Natural_Value (Trimmed (Item), Number)
                             and then Number <= Terminal.App.Splits.Max_Panes
                           then
                              Value.Pane_Tree.Count := Number;
                           else
                              Valid := False;
                           end if;
                        elsif Key = "tree-active" then
                           if Natural_Value (Trimmed (Item), Number)
                             and then Number in 1 .. Terminal.App.Splits.Max_Panes
                           then
                              Value.Pane_Tree.Active := Number;
                           else
                              Valid := False;
                           end if;
                        elsif Key = "tree-root" then
                           if Natural_Value (Trimmed (Item), Number)
                             and then Number <= Terminal.App.Splits.Max_Nodes
                           then
                              Value.Pane_Tree.Root := Number;
                           else
                              Valid := False;
                           end if;
                        elsif Key'Length > 12
                          and then Key (Key'First .. Key'First + 9) =
                            "tree-node-"
                        then
                           declare
                              Suffix : constant Natural :=
                                Ada.Strings.Fixed.Index
                                  (Key, "-", From => Key'First + 10);
                              Node_Number : Natural;
                           begin
                              if Suffix = 0
                                or else not Natural_Value
                                  (Key (Key'First + 10 .. Suffix - 1),
                                   Node_Number)
                                or else Node_Number not in
                                  1 .. Terminal.App.Splits.Max_Nodes
                              then
                                 Valid := False;
                              else
                                 declare
                                    Property : constant String :=
                                      Key (Suffix + 1 .. Key'Last);
                                    Node : Terminal.App.Splits.Serialized_Node
                                      renames Value.Pane_Tree.Nodes (Node_Number);
                                    Clean : constant String := Trimmed (Item);
                                 begin
                                    if Property = "kind" then
                                       if Clean = "empty" then
                                          Node.Kind :=
                                            Terminal.App.Splits.Empty_Tree_Node;
                                       elsif Clean = "pane" then
                                          Node.Kind :=
                                            Terminal.App.Splits.Pane_Tree_Node;
                                       elsif Clean = "split" then
                                          Node.Kind :=
                                            Terminal.App.Splits.Branch_Tree_Node;
                                       else
                                          Valid := False;
                                       end if;
                                    elsif Property = "orientation" then
                                       if Clean = "horizontal" then
                                          Node.Orientation :=
                                            Terminal.App.Splits.Horizontal;
                                       elsif Clean = "vertical" then
                                          Node.Orientation :=
                                            Terminal.App.Splits.Vertical;
                                       else
                                          Valid := False;
                                       end if;
                                    elsif Property = "parent"
                                      or else Property = "first"
                                      or else Property = "second"
                                    then
                                       if Natural_Value (Clean, Number)
                                         and then Number <=
                                           Terminal.App.Splits.Max_Nodes
                                       then
                                          if Property = "parent" then
                                             Node.Parent := Number;
                                          elsif Property = "first" then
                                             Node.First := Number;
                                          else
                                             Node.Second := Number;
                                          end if;
                                       else
                                          Valid := False;
                                       end if;
                                    elsif Property = "weight" then
                                       if Natural_Value (Clean, Number)
                                         and then Number in
                                           1 .. Terminal.App.Splits.Weight_Unit - 1
                                       then
                                          Node.First_Weight := Number;
                                       else
                                          Valid := False;
                                       end if;
                                    elsif Property = "pane" then
                                       if Natural_Value (Clean, Number)
                                         and then Number in
                                           1 .. Terminal.App.Splits.Max_Panes
                                       then
                                          Node.Pane := Number;
                                       else
                                          Valid := False;
                                       end if;
                                    else
                                       Valid := False;
                                    end if;
                                 end;
                              end if;
                           end;
                        elsif Key'Length > 8
                          and then Key (Key'First .. Key'First + 7) = "session-"
                        then
                           declare
                              Suffix : constant Natural :=
                                Ada.Strings.Fixed.Index
                                  (Key, "-", From => Key'First + 8);
                           begin
                              if Suffix = 0
                                or else not Natural_Value
                                  (Key (Key'First + 8 .. Suffix - 1), Number)
                                or else Number not in
                                  1 .. Terminal.App.Sessions.Max_Sessions
                              then
                                 Valid := False;
                              elsif Key (Suffix + 1 .. Key'Last) = "cwd" then
                                 if Item'Length <= Max_Path_Length then
                                    Set_Path
                                      (Value.Entries (Number).Working_Directory,
                                       Item);
                                 else
                                    Valid := False;
                                 end if;
                              elsif Key (Suffix + 1 .. Key'Last) = "label" then
                                 if Item'Length <= Max_Label_Length then
                                    Set_Label
                                      (Value.Entries (Number).Label, Item);
                                 else
                                    Valid := False;
                                 end if;
                              elsif Key (Suffix + 1 .. Key'Last) = "command" then
                                 if Item'Length <= Max_Command_Length then
                                    Set_Command
                                      (Value.Entries (Number).Startup_Command,
                                       Item);
                                 else
                                    Valid := False;
                                 end if;
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
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      if not Seen_Version or else Value.Active > Value.Count then
         Valid := False;
      end if;
      if Valid and then Version = 2 and then Value.Layout = Panes then
         declare
            Restored : Terminal.App.Splits.Split_State;
            Split_Status : Terminal.App.Splits.Split_Status;
         begin
            Terminal.App.Splits.Restore
              (Restored, Value.Pane_Tree, Split_Status);
            if Split_Status /= Terminal.App.Splits.Ok
              or else Natural (Value.Pane_Tree.Count) /= Natural (Value.Count)
              or else Value.Pane_Tree.Active /= Value.Active
            then
               Valid := False;
            end if;
         end;
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
      Tree_Value : Terminal.App.Splits.Split_Tree := Value.Pane_Tree;
      Tree_State : Terminal.App.Splits.Split_State;
      Split_Status : Terminal.App.Splits.Split_Status;
      Temp_Path : constant String := Path & ".tmp";
      Parent : constant String :=
        (if Path = "" then "." else Ada.Directories.Containing_Directory (Path));
      function N (Item : Natural) return String is
        (Ada.Strings.Fixed.Trim (Natural'Image (Item), Ada.Strings.Both));
   begin
      if Path = "" then
         Status := IO_Error;
         return;
      end if;
      --  States produced by older callers only carry the root orientation.
      --  Upgrade those states on write so version 2 always has a complete,
      --  validated tree while retaining source-level compatibility.
      if Value.Layout = Panes and then Tree_Value.Count = 0 then
         Terminal.App.Splits.Initialize (Tree_State);
         for I in 2 .. Value.Count loop
            Terminal.App.Splits.Apply
              (Tree_State,
               (if Value.Orientation = Horizontal
                then Terminal.App.Splits.Split_Horizontal
                else Terminal.App.Splits.Split_Vertical),
               Split_Status);
            if Split_Status /= Terminal.App.Splits.Ok then
               Status := Invalid_Data;
               return;
            end if;
         end loop;
         Terminal.App.Splits.Activate
           (Tree_State, Value.Active, Split_Status);
         if Split_Status /= Terminal.App.Splits.Ok then
            Status := Invalid_Data;
            return;
         end if;
         Tree_Value := Terminal.App.Splits.Tree (Tree_State);
      end if;
      if Parent /= "" and then not Ada.Directories.Exists (Parent) then
         Ada.Directories.Create_Path (Parent);
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Temp_Path);
      Ada.Text_IO.Put_Line (File, "version=2");
      Ada.Text_IO.Put_Line
        (File, "layout=" & Ada.Characters.Handling.To_Lower
           (Layout_Kind'Image (Value.Layout)));
      Ada.Text_IO.Put_Line (File, "count=" & N (Value.Count));
      Ada.Text_IO.Put_Line (File, "active=" & N (Value.Active));
      Ada.Text_IO.Put_Line
        (File, "orientation=" & Ada.Characters.Handling.To_Lower
           (Pane_Orientation'Image (Value.Orientation)));
      if Value.Layout = Panes and then Tree_Value.Count > 0 then
         Ada.Text_IO.Put_Line (File, "tree-count=" & N (Tree_Value.Count));
         Ada.Text_IO.Put_Line (File, "tree-active=" & N (Tree_Value.Active));
         Ada.Text_IO.Put_Line (File, "tree-root=" & N (Tree_Value.Root));
         for I in Tree_Value.Nodes'Range loop
            declare
               Node : Terminal.App.Splits.Serialized_Node
                 renames Tree_Value.Nodes (I);
               Prefix : constant String := "tree-node-" & N (I) & "-";
               Kind : constant String :=
                 (case Node.Kind is
                     when Terminal.App.Splits.Empty_Tree_Node => "empty",
                     when Terminal.App.Splits.Pane_Tree_Node => "pane",
                     when Terminal.App.Splits.Branch_Tree_Node => "split");
            begin
               Ada.Text_IO.Put_Line (File, Prefix & "kind=" & Kind);
               Ada.Text_IO.Put_Line (File, Prefix & "parent=" & N (Node.Parent));
               Ada.Text_IO.Put_Line (File, Prefix & "first=" & N (Node.First));
               Ada.Text_IO.Put_Line (File, Prefix & "second=" & N (Node.Second));
               Ada.Text_IO.Put_Line
                 (File, Prefix & "orientation=" &
                    Ada.Characters.Handling.To_Lower
                      (Terminal.App.Splits.Split_Orientation'Image
                         (Node.Orientation)));
               Ada.Text_IO.Put_Line
                 (File, Prefix & "weight=" & N (Node.First_Weight));
               Ada.Text_IO.Put_Line (File, Prefix & "pane=" & N (Node.Pane));
            end;
         end loop;
      end if;
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
      if Terminal.App.Platform_Files.Replace_File (Temp_Path, Path) then
         Status := Saved;
      else
         Ada.Directories.Delete_File (Temp_Path);
         Status := IO_Error;
      end if;
   exception
      when Ada.IO_Exceptions.Status_Error
         | Ada.IO_Exceptions.Mode_Error
         | Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Layout_Error =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         if Ada.Directories.Exists (Temp_Path) then
            Ada.Directories.Delete_File (Temp_Path);
         end if;
         Status := IO_Error;
   end Save;
end Terminal.App.Workspace;
