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

   function Same_Link
     (Left  : Terminal.Core.Hyperlink;
      Right : Terminal.Core.Hyperlink) return Boolean
   is
   begin
      if Left.Active /= Right.Active
        or else Left.URI_Length /= Right.URI_Length
        or else Left.ID_Length /= Right.ID_Length
      then
         return False;
      elsif not Left.Active then
         return True;
      end if;

      for I in 1 .. Left.URI_Length loop
         if Left.URI (I) /= Right.URI (I) then
            return False;
         end if;
      end loop;

      for I in 1 .. Left.ID_Length loop
         if Left.ID (I) /= Right.ID (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Link;

   function Is_URI_Graphic (Ch : Character) return Boolean is
     (Character'Pos (Ch) > 16#20# and then Character'Pos (Ch) < 16#7F#);

   function Lower (Ch : Character) return Character is
   begin
      if Ch in 'A' .. 'Z' then
         return Character'Val
           (Character'Pos (Ch)
            - Character'Pos ('A')
            + Character'Pos ('a'));
      else
         return Ch;
      end if;
   end Lower;

   function Has_Prefix_Case_Insensitive
     (Text   : String;
      Prefix : String) return Boolean
   is
   begin
      if Text'Length <= Prefix'Length then
         return False;
      end if;

      for I in Prefix'Range loop
         if Lower (Text (Text'First + I - Prefix'First)) /= Lower (Prefix (I)) then
            return False;
         end if;
      end loop;

      return True;
   end Has_Prefix_Case_Insensitive;

   function Supported_URI (URI : String) return Boolean is
   begin
      for Ch of URI loop
         if not Is_URI_Graphic (Ch) then
            return False;
         end if;
      end loop;

      return
        Has_Prefix_Case_Insensitive (URI, "http://")
        or else Has_Prefix_Case_Insensitive (URI, "https://")
        or else Has_Prefix_Case_Insensitive (URI, "mailto:");
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
