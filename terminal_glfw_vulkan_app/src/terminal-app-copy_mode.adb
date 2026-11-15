with Ada.Characters.Handling;
with GNAT.Regpat;
with Terminal.Common.Status;
with Terminal.Core.Snapshot_Editing;

package body Terminal.App.Copy_Mode is
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Common.Code_Point;
   use type GNAT.Regpat.Match_Location;

   procedure Grid_Size
     (Core       : Terminal.Core.Terminal;
      Rows       : out Positive;
      Cols       : out Positive;
      Scrollback : out Natural)
   is
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Core);
   begin
      Rows := Positive (Snapshot.Rows);
      Cols := Positive (Snapshot.Cols);
      Scrollback := Terminal.Core.Scrollback_Row_Count (Core);
      Terminal.Core.Release (Snapshot);
   exception
      when others =>
         Terminal.Core.Release (Snapshot);
         raise;
   end Grid_Size;

   procedure Enter_Copy
     (Item : in out State;
      Core : Terminal.Core.Terminal)
   is
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Core);
   begin
      Item.Mode := Copying;
      Item.Query_Count := 0;
      Item.Has_Match := False;
      Item.Match_Total := 0;
      Item.Match_Index := 0;
      Item.Absolute_Row :=
        Terminal.Core.Scrollback_Row_Count (Core) + Snapshot.Cursor.Row;
      Item.Column := Snapshot.Cursor.Col;
      Item.Match_Last_Column := Item.Column;
      Terminal.Core.Release (Snapshot);
   exception
      when others =>
         Terminal.Core.Release (Snapshot);
         raise;
   end Enter_Copy;

   procedure Enter_Search
     (Item : in out State;
      Core : Terminal.Core.Terminal) is
   begin
      Enter_Copy (Item, Core);
      Item.Mode := Search_Input;
      Item.Query_Count := 0;
      Item.Has_Match := False;
      Item.History_Position := 0;
   end Enter_Search;

   procedure Leave (Item : in out State) is
   begin
      Item.Mode := Inactive;
      Item.Query_Count := 0;
      Item.Has_Match := False;
      Item.Match_Total := 0;
      Item.Match_Index := 0;
   end Leave;

   function Active (Item : State) return Boolean is
     (Item.Mode /= Inactive);

   function Searching (Item : State) return Boolean is
     (Item.Mode = Search_Input);

   procedure Append
     (Item : in out State;
      Code : Terminal.Common.Code_Point) is
   begin
      if Item.Mode = Search_Input
        and then Item.Query_Count < Max_Query_Length
        and then Code /= 0
      then
         Item.Query_Count := Item.Query_Count + 1;
         Item.Query (Item.Query_Count) := Code;
         Item.Has_Match := False;
         Item.Match_Total := 0;
         Item.History_Position := 0;
      end if;
   end Append;

   procedure Backspace (Item : in out State) is
   begin
      if Item.Query_Count > 0 then
         Item.Query (Item.Query_Count) := 0;
         Item.Query_Count := Item.Query_Count - 1;
         Item.Has_Match := False;
         Item.Match_Total := 0;
      end if;
   end Backspace;

   procedure Toggle_Regex (Item : in out State) is
   begin
      Item.Regex_Mode := not Item.Regex_Mode;
      Item.Has_Match := False;
   end Toggle_Regex;

   procedure Toggle_Case (Item : in out State) is
   begin
      Item.Case_Sensitive := not Item.Case_Sensitive;
      Item.Has_Match := False;
   end Toggle_Case;

   procedure Toggle_Whole_Word (Item : in out State) is
   begin
      Item.Whole_Word := not Item.Whole_Word;
      Item.Has_Match := False;
   end Toggle_Whole_Word;

   procedure Remember_Query (Item : in out State) is
   begin
      if Item.Query_Count = 0 then
         return;
      end if;
      if Item.History_Count > 0
        and then Item.History (Item.History_Count).Count = Item.Query_Count
        and then Item.History (Item.History_Count).Query = Item.Query
      then
         Item.History_Position := 0;
         return;
      end if;
      if Item.History_Count = Max_History then
         for I in 1 .. Max_History - 1 loop
            Item.History (I) := Item.History (I + 1);
         end loop;
      else
         Item.History_Count := Item.History_Count + 1;
      end if;
      Item.History (Item.History_Count) :=
        (Query => Item.Query, Count => Item.Query_Count);
      Item.History_Position := 0;
   end Remember_Query;

   procedure History_Move (Item : in out State; Direction : Integer) is
   begin
      if Item.History_Count = 0 then
         return;
      elsif Direction < 0 then
         if Item.History_Position = 0 then
            Item.History_Position := Item.History_Count;
         elsif Item.History_Position > 1 then
            Item.History_Position := Item.History_Position - 1;
         end if;
      elsif Direction > 0 and then Item.History_Position > 0 then
         if Item.History_Position < Item.History_Count then
            Item.History_Position := Item.History_Position + 1;
         else
            Item.History_Position := 0;
            Item.Query_Count := 0;
            Item.Query := (others => 0);
            return;
         end if;
      end if;
      if Item.History_Position > 0 then
         Item.Query := Item.History (Item.History_Position).Query;
         Item.Query_Count := Item.History (Item.History_Position).Count;
      end if;
      Item.Has_Match := False;
   end History_Move;

   function Query_Length (Item : State) return Natural is (Item.Query_Count);

   function Status_Label (Item : State) return String is
      Result : String (1 .. Max_Query_Length);
      Last : Natural := 0;
   begin
      if Item.Mode = Inactive then
         return "";
      elsif Item.Mode = Copying then
         return "COPY";
      end if;
      for I in 1 .. Item.Query_Count loop
         Last := Last + 1;
         Result (Last) :=
           (if Item.Query (I) in 32 .. 126
            then Standard.Character'Val (Item.Query (I))
            else '?');
      end loop;
      return
        "SEARCH "
        & (if Item.Regex_Mode then "[regex" else "[text")
        & (if Item.Case_Sensitive then ",case" else ",nocase")
        & (if Item.Whole_Word then ",word] " else "] ")
        & Result (1 .. Last)
        & (if not Item.Regex_Valid then " [invalid regex]"
           elsif Item.Query_Count = 0 then ""
           elsif not Item.Has_Match then " [0/0]"
           else " [" & Natural'Image (Item.Match_Index)
             & "/" & Natural'Image (Item.Match_Total) & "]");
   end Status_Label;

   procedure Find
     (Item    : in out State;
      Core    : Terminal.Core.Terminal;
      Backward : Boolean := False;
      Restart : Boolean := False)
   is
      Live : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Core);
      Scrollback : constant Natural := Terminal.Core.Scrollback_Row_Count (Core);
      Live_Rows : constant Positive := Positive (Live.Rows);
      Cols : constant Positive := Positive (Live.Cols);
      Total_Rows : constant Positive := Scrollback + Live_Rows;
      Current_Position : constant Natural :=
        (if Restart or else not Item.Has_Match or else Item.Absolute_Row = 0
         then (if Backward then Total_Rows * Cols + 1 else 0)
         else (Item.Absolute_Row - 1) * Cols + Item.Column);

      type Candidate is record
         Present : Boolean := False;
         Row, First_Col, Last_Col : Positive := 1;
         Index : Natural := 0;
      end record;
      First, Last, Before, After : Candidate;

      function Content
        (Absolute_Row : Positive;
         Col          : Positive) return Terminal.Core.Cell_Content
      is
      begin
         if Absolute_Row <= Scrollback then
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Scrollback_Cell_At (Core, Absolute_Row, Col);
            begin
               return
                 (Includes_Link => False,
                  Kind => Cell.Kind,
                  Text => Cell.Text,
                  Style => Cell.Style,
                  Image => Cell.Image);
            end;
         else
            return Terminal.Core.Cell_Content_At
              (Live, Absolute_Row - Scrollback, Col);
         end if;
      end Content;

      function Fold (Value : Terminal.Common.Code_Point)
        return Terminal.Common.Code_Point is
      begin
         if not Item.Case_Sensitive and then Value in 0 .. 127 then
            return Terminal.Common.Code_Point
              (Character'Pos
                 (Ada.Characters.Handling.To_Lower
                    (Character'Val (Value))));
         end if;
         return Value;
      end Fold;
      function Is_Word (Value : Terminal.Common.Code_Point) return Boolean is
        (Value > 127
         or else Value = Character'Pos ('_')
         or else Value in Character'Pos ('0') .. Character'Pos ('9')
         or else Value in Character'Pos ('A') .. Character'Pos ('Z')
         or else Value in Character'Pos ('a') .. Character'Pos ('z'));

      function Word_Boundary
        (Absolute_Row : Positive;
         First_Col, Last_Col : Positive) return Boolean is
        (not Item.Whole_Word
         or else
           ((First_Col = 1
             or else not Is_Word
               (Content (Absolute_Row, First_Col - 1).Text.Code_Point))
            and then
            (Last_Col = Cols
             or else not Is_Word
               (Content (Absolute_Row, Last_Col + 1).Text.Code_Point))));

      function Literal_Matches
        (Absolute_Row : Positive;
         First_Col    : Positive;
         Last_Col     : out Positive) return Boolean
      is
         Col : Positive := First_Col;
      begin
         for Q in 1 .. Item.Query_Count loop
            while Col <= Cols
              and then Content (Absolute_Row, Col).Kind =
                Terminal.Core.Wide_Continuation
            loop
               exit when Col = Cols;
               Col := Col + 1;
            end loop;
            if Col > Cols
              or else Content (Absolute_Row, Col).Kind /= Terminal.Core.Character
              or else Fold (Content (Absolute_Row, Col).Text.Code_Point) /=
                Fold (Item.Query (Q))
            then
               Last_Col := First_Col;
               return False;
            end if;
            Last_Col := Col;
            exit when Q = Item.Query_Count;
            if Col = Cols then
               return False;
            end if;
            Col := Col + 1;
         end loop;
         return Word_Boundary (Absolute_Row, First_Col, Last_Col);
      end Literal_Matches;

      procedure Consider
        (Row, First_Col, Last_Col : Positive) is
         Position : constant Natural := (Row - 1) * Cols + First_Col;
         Value : Candidate;
      begin
         Item.Match_Total := Item.Match_Total + 1;
         Value := (True, Row, First_Col, Last_Col, Item.Match_Total);
         if not First.Present then First := Value; end if;
         Last := Value;
         if Position < Current_Position then
            Before := Value;
         elsif Position > Current_Position and then not After.Present then
            After := Value;
         end if;
      end Consider;

      procedure Choose (Value : Candidate) is
      begin
         if Value.Present then
            Item.Absolute_Row := Value.Row;
            Item.Column := Value.First_Col;
            Item.Match_Last_Column := Value.Last_Col;
            Item.Match_Index := Value.Index;
            Item.Has_Match := True;
         else
            Item.Has_Match := False;
            Item.Match_Index := 0;
         end if;
      end Choose;
   begin
      Item.Match_Total := 0;
      Item.Match_Index := 0;
      Item.Regex_Valid := True;
      if Item.Query_Count = 0 then
         Item.Has_Match := False;
         Terminal.Core.Release (Live);
         return;
      end if;

      if Item.Regex_Mode then
         declare
            Expression : String (1 .. Item.Query_Count);
            Matcher : GNAT.Regpat.Pattern_Matcher (4_096);
            Final_Size : GNAT.Regpat.Program_Size;
         begin
            for I in Expression'Range loop
               Expression (I) :=
                 (if Item.Query (I) in 1 .. 127
                  then Character'Val (Item.Query (I)) else '?');
            end loop;
            GNAT.Regpat.Compile
              (Matcher, Expression, Final_Size,
               Flags => (if Item.Case_Sensitive then GNAT.Regpat.No_Flags
                         else GNAT.Regpat.Case_Insensitive));
            for Row in 1 .. Total_Rows loop
               declare
                  Text : String (1 .. Cols);
                  Search_First : Positive := 1;
                  Matches : GNAT.Regpat.Match_Array (0 .. 0);
               begin
                  for Col in Text'Range loop
                     declare
                        Cell : constant Terminal.Core.Cell_Content :=
                          Content (Row, Col);
                     begin
                        Text (Col) :=
                          (if Cell.Kind = Terminal.Core.Character
                             and then Cell.Text.Code_Point in 1 .. 127
                           then Character'Val (Cell.Text.Code_Point) else ' ');
                     end;
                  end loop;
                  while Search_First <= Cols loop
                     GNAT.Regpat.Match
                       (Matcher, Text, Matches, Data_First => Search_First);
                     exit when Matches (0) = GNAT.Regpat.No_Match;
                     declare
                        Match_First : constant Positive :=
                          Positive'Min (Cols, Positive (Matches (0).First));
                        Match_Last : constant Positive :=
                          Positive'Min
                            (Cols, Positive'Max
                               (Match_First, Matches (0).Last));
                     begin
                        if Word_Boundary (Row, Match_First, Match_Last) then
                           Consider (Row, Match_First, Match_Last);
                        end if;
                        exit when Match_First = Cols;
                        Search_First := Match_First + 1;
                     end;
                  end loop;
               end;
            end loop;
         exception
            when GNAT.Regpat.Expression_Error | Storage_Error =>
               Item.Regex_Valid := False;
               Item.Has_Match := False;
               Item.Match_Total := 0;
         end;
      else
         for Row in 1 .. Total_Rows loop
            for Col in 1 .. Cols loop
               declare
                  Match_Last : Positive := Col;
               begin
                  if Literal_Matches (Row, Col, Match_Last) then
                     Consider (Row, Col, Match_Last);
                  end if;
               end;
            end loop;
         end loop;
      end if;
      if Item.Regex_Valid then
         Choose
           ((if Backward
             then (if Before.Present then Before else Last)
             else (if After.Present then After else First)));
      end if;
      Terminal.Core.Release (Live);
   exception
      when others =>
         Terminal.Core.Release (Live);
         raise;
   end Find;

   function Match_Found (Item : State) return Boolean is (Item.Has_Match);

   procedure Apply_Match_Highlights
     (Item     : State;
      Snapshot : in out Terminal.Core.Render_Snapshot)
   is
      use type Terminal.Core.Cell_Kind;
      Rows : constant Natural := Snapshot.Rows;
      Cols : constant Natural := Snapshot.Cols;
      function Fold (Value : Terminal.Common.Code_Point)
        return Terminal.Common.Code_Point is
      begin
         if not Item.Case_Sensitive and then Value in 0 .. 127 then
            return Terminal.Common.Code_Point
              (Character'Pos
                 (Ada.Characters.Handling.To_Lower (Character'Val (Value))));
         end if;
         return Value;
      end Fold;
      function Is_Word (Value : Terminal.Common.Code_Point) return Boolean is
        (Value > 127
         or else Value = Character'Pos ('_')
         or else Value in Character'Pos ('0') .. Character'Pos ('9')
         or else Value in Character'Pos ('A') .. Character'Pos ('Z')
         or else Value in Character'Pos ('a') .. Character'Pos ('z'));
      function Boundary
        (Row, First_Col, Last_Col : Positive) return Boolean is
        (not Item.Whole_Word
         or else
           ((First_Col = 1
             or else not Is_Word
               (Terminal.Core.Cell_Content_At
                  (Snapshot, Row, First_Col - 1).Text.Code_Point))
            and then
            (Last_Col = Cols
             or else not Is_Word
               (Terminal.Core.Cell_Content_At
                  (Snapshot, Row, Last_Col + 1).Text.Code_Point))));
      procedure Mark (Row, First_Col, Last_Col : Positive) is
      begin
         for Col in First_Col .. Last_Col loop
            declare
               Index : constant Positive := (Row - 1) * Cols + Col;
               Style : Terminal.Core.Cell_Style :=
                 Terminal.Core.Cell_Style_At_Index (Snapshot, Index);
            begin
               Style.Underline := True;
               Terminal.Core.Snapshot_Editing.Set_Cell_Style
                 (Snapshot, Index, Style);
            end;
         end loop;
         Terminal.Core.Snapshot_Editing.Set_Dirty_Row (Snapshot, Row, True);
      end Mark;
   begin
      if not Searching (Item) or else Item.Query_Count = 0
        or else Rows = 0 or else Cols = 0
      then
         return;
      end if;
      if Item.Regex_Mode then
         declare
            Expression : String (1 .. Item.Query_Count);
            Matcher : GNAT.Regpat.Pattern_Matcher (4_096);
            Final_Size : GNAT.Regpat.Program_Size;
         begin
            for I in Expression'Range loop
               Expression (I) :=
                 (if Item.Query (I) in 1 .. 127
                  then Character'Val (Item.Query (I)) else '?');
            end loop;
            GNAT.Regpat.Compile
              (Matcher, Expression, Final_Size,
               Flags => (if Item.Case_Sensitive then GNAT.Regpat.No_Flags
                         else GNAT.Regpat.Case_Insensitive));
            for Row in 1 .. Rows loop
               declare
                  Text : String (1 .. Cols);
                  Search_First : Positive := 1;
                  Found : GNAT.Regpat.Match_Array (0 .. 0);
               begin
                  for Col in Text'Range loop
                     declare
                        Cell : constant Terminal.Core.Cell_Content :=
                          Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
                     begin
                        Text (Col) :=
                          (if Cell.Kind = Terminal.Core.Character
                             and then Cell.Text.Code_Point in 1 .. 127
                           then Character'Val (Cell.Text.Code_Point) else ' ');
                     end;
                  end loop;
                  while Search_First <= Cols loop
                     GNAT.Regpat.Match
                       (Matcher, Text, Found, Data_First => Search_First);
                     exit when Found (0) = GNAT.Regpat.No_Match;
                     declare
                        First_Col : constant Positive :=
                          Positive'Min (Cols, Positive (Found (0).First));
                        Last_Col : constant Positive :=
                          Positive'Min
                            (Cols, Positive'Max (First_Col, Found (0).Last));
                     begin
                        if Boundary (Row, First_Col, Last_Col) then
                           Mark (Row, First_Col, Last_Col);
                        end if;
                        exit when First_Col = Cols;
                        Search_First := First_Col + 1;
                     end;
                  end loop;
               end;
            end loop;
         exception
            when GNAT.Regpat.Expression_Error | Storage_Error => null;
         end;
         return;
      end if;
      for Row in 1 .. Rows loop
         for Col in 1 .. Cols loop
            declare
               Cursor : Positive := Col;
               Last_Col : Positive := Col;
               Matches : Boolean := True;
            begin
               for Q in 1 .. Item.Query_Count loop
                  while Cursor <= Cols
                    and then Terminal.Core.Cell_Content_At
                      (Snapshot, Row, Cursor).Kind = Terminal.Core.Wide_Continuation
                  loop
                     exit when Cursor = Cols;
                     Cursor := Cursor + 1;
                  end loop;
                  if Cursor > Cols
                    or else Terminal.Core.Cell_Content_At
                      (Snapshot, Row, Cursor).Kind /= Terminal.Core.Character
                    or else Fold (Terminal.Core.Cell_Content_At
                      (Snapshot, Row, Cursor).Text.Code_Point) /=
                      Fold (Item.Query (Q))
                  then
                     Matches := False;
                     exit;
                  end if;
                  Last_Col := Cursor;
                  exit when Q = Item.Query_Count;
                  if Cursor = Cols then
                     Matches := False;
                     exit;
                  end if;
                  Cursor := Cursor + 1;
               end loop;
               if Matches and then Boundary (Row, Col, Last_Col) then
                  Mark (Row, Col, Last_Col);
               end if;
            end;
         end loop;
      end loop;
   end Apply_Match_Highlights;

   procedure Move
     (Item      : in out State;
      Core      : Terminal.Core.Terminal;
      Row_Delta : Integer;
      Col_Delta : Integer)
   is
      Rows, Cols : Positive;
      Scrollback : Natural;
      Total_Rows : Positive;
      New_Row : Integer;
      New_Col : Integer;
   begin
      Grid_Size (Core, Rows, Cols, Scrollback);
      Total_Rows := Scrollback + Rows;
      New_Row := Integer (Item.Absolute_Row) + Row_Delta;
      New_Col := Integer (Item.Column) + Col_Delta;
      Item.Absolute_Row := Natural (Integer'Max (1, Integer'Min (New_Row, Integer (Total_Rows))));
      Item.Column := Positive (Integer'Max (1, Integer'Min (New_Col, Integer (Cols))));
      Item.Match_Last_Column := Item.Column;
      Item.Has_Match := False;
   end Move;

   procedure Move_Page
     (Item      : in out State;
      Core      : Terminal.Core.Terminal;
      Direction : Integer)
   is
      Rows, Cols : Positive;
      Scrollback : Natural;
   begin
      Grid_Size (Core, Rows, Cols, Scrollback);
      Move (Item, Core, Direction * Integer (Rows), 0);
   end Move_Page;

   procedure Move_Row_Edge
     (Item : in out State;
      Core : Terminal.Core.Terminal;
      Last : Boolean)
   is
      Rows, Cols : Positive;
      Scrollback : Natural;
   begin
      Grid_Size (Core, Rows, Cols, Scrollback);
      Item.Column := (if Last then Cols else 1);
      Item.Match_Last_Column := Item.Column;
      Item.Has_Match := False;
   end Move_Row_Edge;

   function Recommended_Offset
     (Item : State;
      Core : Terminal.Core.Terminal) return Natural
   is
      Rows, Cols : Positive;
      Scrollback : Natural;
      Start_Row : Positive;
   begin
      Grid_Size (Core, Rows, Cols, Scrollback);
      if Item.Absolute_Row = 0 or else Item.Absolute_Row > Scrollback then
         return 0;
      end if;
      Start_Row :=
        Positive'Max
          (1,
           Positive (Item.Absolute_Row)
             - Natural'Min (Item.Absolute_Row - 1, Rows / 2));
      return Natural'Min (Scrollback, Scrollback - Start_Row + 1);
   end Recommended_Offset;

   function Visible_Position
     (Item   : State;
      Core   : Terminal.Core.Terminal;
      Offset : Natural) return Terminal.App.Selection.Cell_Position
   is
      Rows, Cols : Positive;
      Scrollback : Natural;
      Effective : Natural;
      First_Absolute : Positive;
      Local_Row : Integer;
   begin
      Grid_Size (Core, Rows, Cols, Scrollback);
      Effective := Natural'Min (Offset, Scrollback);
      First_Absolute :=
        (if Effective = 0 then Scrollback + 1
         else Scrollback - Effective + 1);
      Local_Row := Integer (Item.Absolute_Row) - Integer (First_Absolute) + 1;
      return
        (Row => Positive (Integer'Max (1, Integer'Min (Local_Row, Integer (Rows)))),
         Col => Positive'Min (Item.Column, Cols));
   end Visible_Position;

   procedure Select_Cursor
     (Item      : State;
      Core      : Terminal.Core.Terminal;
      Offset    : Natural;
      Selection : in out Terminal.App.Selection.Selection_State;
      Extend    : Boolean := False)
   is
      First : constant Terminal.App.Selection.Cell_Position :=
        Visible_Position (Item, Core, Offset);
      Last : Terminal.App.Selection.Cell_Position := First;
      Rows, Cols : Positive;
      Scrollback : Natural;
   begin
      Grid_Size (Core, Rows, Cols, Scrollback);
      Last.Col := Positive'Min (Item.Match_Last_Column, Cols);
      if Extend then
         Terminal.App.Selection.Extend_Selection (Selection, Last);
      else
         Terminal.App.Selection.Begin_Selection (Selection, First);
         Terminal.App.Selection.Finish_Selection (Selection, Last);
      end if;
   end Select_Cursor;
end Terminal.App.Copy_Mode;
