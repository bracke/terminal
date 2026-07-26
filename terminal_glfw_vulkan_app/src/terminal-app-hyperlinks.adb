with Interfaces.C;
with Interfaces.C.Strings;

package body Terminal.App.Hyperlinks is
   use type Interfaces.C.int;
   use type Terminal.Core.Cell_Array_Access;
   use type Terminal.Core.Cell_Kind;

   function c_system (Command : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "system";

   function Link_At
     (Snapshot : Terminal.Core.Render_Snapshot;
      Position : Terminal.App.Selection.Cell_Position)
      return Terminal.Core.Hyperlink
   is
      Cell : Terminal.Core.Cell;
   begin
      if Snapshot.Rows = 0
        or else Snapshot.Cols = 0
        or else Snapshot.Cells = null
        or else Position.Row > Snapshot.Rows
        or else Position.Col > Snapshot.Cols
      then
         return (others => <>);
      end if;

      Cell := Terminal.Core.Cell_At (Snapshot, Position.Row, Position.Col);
      if Cell.Link.Active then
         return Cell.Link;
      elsif Cell.Kind = Terminal.Core.Wide_Continuation
        and then Position.Col > 1
      then
         return
           Terminal.Core.Cell_At
             (Snapshot, Position.Row, Position.Col - 1).Link;
      else
         return (others => <>);
      end if;
   end Link_At;

   function Supported_URI (URI : String) return Boolean is
   begin
      return
        (URI'Length > 7 and then URI (URI'First .. URI'First + 6) = "http://")
        or else
          (URI'Length > 8
           and then URI (URI'First .. URI'First + 7) = "https://")
        or else
          (URI'Length > 7
           and then URI (URI'First .. URI'First + 6) = "mailto:");
   end Supported_URI;

   function Open_Command (URI : String) return String is
      Result : String (1 .. Max_Command_Length);
      Last   : Natural := 0;

      procedure Append (Ch : Character) is
      begin
         if Last < Result'Last then
            Last := Last + 1;
            Result (Last) := Ch;
         end if;
      end Append;

      procedure Append_String (Text : String) is
      begin
         for Ch of Text loop
            Append (Ch);
         end loop;
      end Append_String;
   begin
      if not Supported_URI (URI) then
         return "";
      end if;

      Append_String ("xdg-open '");
      for Ch of URI loop
         if Ch = ''' then
            Append_String ("'\''");
         else
            Append (Ch);
         end if;
      end loop;
      Append (''');

      if Last = Result'Last then
         return "";
      else
         return Result (1 .. Last);
      end if;
   end Open_Command;

   procedure Activate
     (Link   : Terminal.Core.Hyperlink;
      Status : out Activation_Status)
   is
      URI_Text : constant String :=
        (if Link.URI_Length = 0 then "" else Link.URI (1 .. Link.URI_Length));
      Command  : constant String := Open_Command (URI_Text);
      C_Command : Interfaces.C.Strings.chars_ptr;
      Result    : Interfaces.C.int;
   begin
      if not Link.Active or else Link.URI_Length = 0 then
         Status := No_Link;
      elsif not Supported_URI (URI_Text) then
         Status := Unsupported_URI;
      elsif Command = "" then
         Status := Command_Too_Long;
      else
         C_Command := Interfaces.C.Strings.New_String (Command);
         Result := c_system (C_Command);
         Interfaces.C.Strings.Free (C_Command);
         Status := (if Result = 0 then Ok else Launch_Failed);
      end if;
   end Activate;
end Terminal.App.Hyperlinks;
