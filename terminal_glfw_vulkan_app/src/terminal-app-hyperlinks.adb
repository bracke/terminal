with Terminal.App.Platform_Launcher;
with Terminal.Common.Status;

package body Terminal.App.Hyperlinks is
   use type Terminal.App.Platform_Launcher.Launch_Status;
   use type Terminal.Core.Cell_Kind;

   function Link_At
     (Snapshot : Terminal.Core.Render_Snapshot;
      Position : Terminal.App.Selection.Cell_Position)
      return Terminal.Core.Hyperlink
   is
      Cell : Terminal.Core.Cell;
   begin
      if Snapshot.Rows = 0
        or else Snapshot.Cols = 0
        or else Terminal.Core.Cell_Count (Snapshot) = 0
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
         declare
            function Cell_Character (Col : Positive) return Character is
               Candidate : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snapshot, Position.Row, Col);
            begin
               if Candidate.Kind = Terminal.Core.Character
                 and then Candidate.Text.Code_Point in 33 .. 126
               then
                  return Character'Val (Candidate.Text.Code_Point);
               else
                  return ' ';
               end if;
            end Cell_Character;
            function Separator (Ch : Character) return Boolean is
              (Ch = ' ' or else Ch in '"' | ''' | '<' | '>');
            First : Positive := Position.Col;
            Last  : Positive := Position.Col;
            Link  : Terminal.Core.Hyperlink;
            URI_First : Positive;
            URI_Last  : Natural;
            Is_Path : Boolean := False;
            Prefix : constant String := "file://";
            Count : Natural := 0;
         begin
            if Separator (Cell_Character (Position.Col)) then
               return (others => <>);
            end if;
            while First > 1 and then not Separator (Cell_Character (First - 1)) loop
               First := First - 1;
            end loop;
            while Last < Snapshot.Cols
              and then not Separator (Cell_Character (Last + 1))
            loop
               Last := Last + 1;
            end loop;
            while First <= Last and then Cell_Character (First) in '(' | '[' | '{' loop
               First := First + 1;
            end loop;
            while Last >= First
              and then Cell_Character (Last) in '.' | ',' | ';' | '!' | '?'
                | ')' | ']' | '}'
            loop
               exit when Last = 1;
               Last := Last - 1;
            end loop;
            if Position.Col < First or else Position.Col > Last then
               return (others => <>);
            end if;
            URI_First := First;
            URI_Last := Last;
            Is_Path := Cell_Character (First) = '/' and then Last > First;
            if Is_Path then
               --  Strip conventional :line and :line:column suffixes before
               --  handing an absolute path to the desktop opener.
               while URI_Last > URI_First and then Cell_Character (URI_Last) in '0' .. '9' loop
                  URI_Last := URI_Last - 1;
               end loop;
               if Cell_Character (URI_Last) = ':' then
                  URI_Last := URI_Last - 1;
                  while URI_Last > URI_First and then Cell_Character (URI_Last) in '0' .. '9' loop
                     URI_Last := URI_Last - 1;
                  end loop;
                  if Cell_Character (URI_Last) = ':' then
                     URI_Last := URI_Last - 1;
                  end if;
               else
                  URI_Last := Last;
               end if;
            end if;
            declare
               Token : String (1 .. Last - First + 1);
            begin
               for I in Token'Range loop
                  Token (I) := Cell_Character (First + I - 1);
               end loop;
               if not Is_Path and then not Supported_URI (Token) then
                  return (others => <>);
               end if;
            end;
            Link := (others => <>);
            Link.Active := True;
            if Is_Path then
               for Ch of Prefix loop
                  Count := Count + 1;
                  Link.URI (Count) := Ch;
               end loop;
            end if;
            for Col in URI_First .. URI_Last loop
               exit when Count = Terminal.Core.Max_Hyperlink_URI_Length;
               Count := Count + 1;
               Link.URI (Count) := Cell_Character (Col);
            end loop;
            Link.URI_Length := Count;
            return Link;
         end;
      end if;
   end Link_At;

   function Same_Link
     (Left  : Terminal.Core.Hyperlink;
      Right : Terminal.Core.Hyperlink) return Boolean
      is (Terminal.Core.Same_Hyperlink (Left, Right));

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
        or else Has_Prefix_Case_Insensitive (URI, "mailto:")
        or else Has_Prefix_Case_Insensitive (URI, "file://");
   end Supported_URI;

   function Link_Label (Link : Terminal.Core.Hyperlink) return String is
      URI_Text : constant String :=
        (if Link.URI_Length = 0 then "" else Link.URI (1 .. Link.URI_Length));
      Last : Natural := 0;
      Result : String (1 .. Max_Link_Label_Length);
   begin
      if not Link.Active
        or else Link.URI_Length = 0
        or else not Supported_URI (URI_Text)
      then
         return "";
      end if;

      for Ch of URI_Text loop
         exit when Last = Result'Last;
         Last := Last + 1;
         Result (Last) := Ch;
      end loop;

      return Result (1 .. Last);
   end Link_Label;

   function Status_Label (Link : Terminal.Core.Hyperlink) return String is
      URI_Text : constant String :=
        (if Link.URI_Length = 0 then "" else Link.URI (1 .. Link.URI_Length));
      Prefix : constant String :=
        (if Link.Active
           and then Link.URI_Length > 0
           and then Supported_URI (URI_Text)
         then "Open "
         else "Unsupported link ");
      Last : Natural := 0;
      Result : String (1 .. Max_Status_Label_Length);

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
      if not Link.Active or else Link.URI_Length = 0 then
         return "";
      end if;

      Append_String (Prefix);
      for Ch of URI_Text loop
         exit when Last = Result'Last;
         if Is_URI_Graphic (Ch) then
            Append (Ch);
         else
            Append ('?');
         end if;
      end loop;

      return Result (1 .. Last);
   end Status_Label;

   function Activation_Status_Label (Status : Activation_Status) return String is
   begin
      case Status is
         when Ok =>
            return "Link opened";
         when No_Link =>
            return "No link under pointer";
         when Unsupported_URI =>
            return "Unsupported link target";
         when Launch_Failed =>
            return "Link launcher failed";
      end case;
   end Activation_Status_Label;

   function Hover_Title
     (Base_Title : String;
      Link       : Terminal.Core.Hyperlink) return String
   is
      Label : constant String := Link_Label (Link);
      Prefix : constant String :=
        (if Base_Title'Length = 0 then "Ada Terminal" else Base_Title);
      Separator : constant String := " - ";
      Last : Natural := 0;
      Result : String (1 .. Max_Hover_Title_Length);

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
      if Label = "" then
         return Prefix;
      end if;

      Append_String (Prefix);
      Append_String (Separator);
      Append_String (Label);
      return Result (1 .. Last);
   end Hover_Title;

   procedure Activate
     (Link   : Terminal.Core.Hyperlink;
      Status : out Activation_Status)
   is
      URI_Text : constant String :=
        (if Link.URI_Length = 0 then "" else Link.URI (1 .. Link.URI_Length));
      Launch : Terminal.App.Platform_Launcher.Launch_Status;
   begin
      if not Link.Active or else Link.URI_Length = 0 then
         Status := No_Link;
      elsif not Supported_URI (URI_Text) then
         Status := Unsupported_URI;
      else
         Terminal.App.Platform_Launcher.Open_URI (URI_Text, Launch);
         Status :=
           (if Launch = Terminal.App.Platform_Launcher.Opened
            then Ok
            else Launch_Failed);
      end if;
   end Activate;

   procedure Begin_Hints
     (State    : in out Hint_State;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
      Previous : Terminal.Core.Hyperlink;
   begin
      State.Enabled := False;
      State.Count := 0;
      State.Current := 1;
      State.Items := (others => <>);
      for Row in 1 .. Snapshot.Rows loop
         Previous := (others => <>);
         for Col in 1 .. Snapshot.Cols loop
            declare
               Position : constant Terminal.App.Selection.Cell_Position :=
                 (Row => Row, Col => Col);
               Link : constant Terminal.Core.Hyperlink :=
                 Link_At (Snapshot, Position);
            begin
               if Link.Active and then Link_Label (Link) /= "" then
                  if Previous.Active and then Same_Link (Previous, Link) then
                     State.Items (State.Count).Last := Position;
                  elsif State.Count < Max_Link_Hints then
                     State.Count := State.Count + 1;
                     State.Items (State.Count) :=
                       (Link => Link, First => Position, Last => Position);
                  end if;
               end if;
               Previous := Link;
            end;
         end loop;
      end loop;
      State.Enabled := State.Count > 0;
      State.Current := 1;
   end Begin_Hints;

   procedure Move_Hint (State : in out Hint_State; Offset : Integer) is
      Zero_Based : Integer;
   begin
      if not State.Enabled or else State.Count = 0 then
         return;
      end if;
      Zero_Based :=
        (Integer (State.Current) - 1 + Offset) mod Integer (State.Count);
      State.Current := Hint_Index (Zero_Based + 1);
   end Move_Hint;

   procedure Leave_Hints (State : in out Hint_State) is
   begin
      State.Enabled := False;
      State.Count := 0;
      State.Current := 1;
      State.Items := (others => <>);
   end Leave_Hints;

   function Hints_Active (State : Hint_State) return Boolean is
     (State.Enabled and then State.Count > 0);

   function Hint_Count (State : Hint_State) return Natural is (State.Count);

   function Current_Hint_Link (State : Hint_State) return Terminal.Core.Hyperlink is
     (if Hints_Active (State)
      then State.Items (State.Current).Link else (others => <>));

   function Current_Hint_First
     (State : Hint_State) return Terminal.App.Selection.Cell_Position is
     (if Hints_Active (State)
      then State.Items (State.Current).First else (others => 1));

   function Current_Hint_Last
     (State : Hint_State) return Terminal.App.Selection.Cell_Position is
     (if Hints_Active (State)
      then State.Items (State.Current).Last else (others => 1));

   function Hint_Status_Label (State : Hint_State) return String is
   begin
      if not Hints_Active (State) then
         return "";
      end if;
      return
        "LINK " & Terminal.Common.Status.Trimmed_Natural (State.Current)
        & "/" & Terminal.Common.Status.Trimmed_Natural (State.Count);
   end Hint_Status_Label;
end Terminal.App.Hyperlinks;
