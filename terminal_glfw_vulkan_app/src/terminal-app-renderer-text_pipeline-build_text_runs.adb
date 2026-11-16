separate (Terminal.App.Renderer.Text_Pipeline)
procedure Build_Text_Runs
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot;
   Cache_Index : Terminal.App.Splits.Pane_Index)
is
   Cache : Terminal.App.Renderer_State.Text_Run_Cache renames
     R.Frame_State.Text_Run_Caches (Cache_Index);
   Current_Origin_X : constant Natural := Origin_X (R);
   Current_Origin_Y : constant Natural := Origin_Y (R);

   procedure Release_Cache is
   begin
      if Cache.Items /= null then
         for Row of Cache.Items.all loop
            Free_Cached_Runs (Row.Runs);
            Free_Cached_Rectangles (Row.Rectangles);
            Free_Cached_Glyphs (Row.Glyphs);
            Free_Cached_Colour_Glyphs (Row.Colour_Glyphs);
         end loop;
         Free_Cached_Rows (Cache.Items);
      end if;
      Cache := (others => <>);
   end Release_Cache;

   procedure Prepare_Cache is
   begin
      if Cache.Initialized
        and then Cache.Stream_ID = Snapshot.Graphics_Stream
        and then Cache.Alternate_Screen = Snapshot.Alternate_Screen
        and then Cache.Screen_Generation = Snapshot.Screen_Generation
        and then Cache.Rows = Snapshot.Rows
        and then Cache.Cols = Snapshot.Cols
        and then Cache.Origin_X = Current_Origin_X
        and then Cache.Origin_Y = Current_Origin_Y
      then
         return;
      end if;
      Release_Cache;
      Cache.Items := new Terminal.App.Renderer_State.Cached_Text_Row_Array
        (1 .. Snapshot.Rows);
      Cache.Stream_ID := Snapshot.Graphics_Stream;
      Cache.Alternate_Screen := Snapshot.Alternate_Screen;
      Cache.Screen_Generation := Snapshot.Screen_Generation;
      Cache.Rows := Snapshot.Rows;
      Cache.Cols := Snapshot.Cols;
      Cache.Origin_X := Current_Origin_X;
      Cache.Origin_Y := Current_Origin_Y;
      Cache.Initialized := True;
   exception
      when Storage_Error =>
         Release_Cache;
         R.Frame_State.Frame_Command_Overflowed := True;
   end Prepare_Cache;

   procedure Account (Run : RM.Text_Run_Command) is
   begin
      R.Text_State.Shaped_Glyph_Count :=
        R.Text_State.Shaped_Glyph_Count + Natural (Run.Shaped_Glyph_Count);
      if Run.Fallback_Glyphs then
         R.Text_State.Text_Fallback_Run_Count :=
           R.Text_State.Text_Fallback_Run_Count + 1;
      end if;
      if Run.Shape_Status = RM.Needs_Shaping_Backend then
         R.Text_State.Shaping_Fallback_Count :=
           R.Text_State.Shaping_Fallback_Count + 1;
      end if;
   end Account;
begin
   Prepare_Cache;
   if not Cache.Initialized then
      return;
   end if;
   for Row in 1 .. Snapshot.Rows loop
      declare
         Col : Positive := 1;
         Row_Has_LTR : Boolean := False;
         Row_Has_RTL : Boolean := False;
         Row_Run_First : constant Positive := R.Frame_State.Text_Run_Count + 1;
         Cached : Terminal.App.Renderer_State.Cached_Text_Row renames
           Cache.Items (Row);
         Reuse : constant Boolean :=
           Cached.Text_Valid
           and then not Terminal.Core.Dirty_Row (Snapshot, Row)
           and then
             (Snapshot.Cursor = Cache.Last_Cursor
              or else
                (Row /= Snapshot.Cursor.Row
                 and then Row /= Cache.Last_Cursor.Row));
      begin
         if Reuse then
            if Cached.Count > 0 then
               declare
                  Capacity_Ok : Boolean;
               begin
                  Frame_Lifecycle.Ensure_Text_Run_Capacity
                    (R, R.Frame_State.Text_Run_Count + Cached.Count, Capacity_Ok);
                  if not Capacity_Ok then
                     R.Frame_State.Frame_Command_Overflowed := True;
                     return;
                  end if;
               end;
               for I in 1 .. Cached.Count loop
                  R.Frame_State.Text_Run_Count :=
                    R.Frame_State.Text_Run_Count + 1;
                  R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count) :=
                    Cached.Runs (I);
                  Account (Cached.Runs (I));
               end loop;
            end if;
         else
         Cached.Draw_Valid := False;
         while Col <= Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell_Content :=
                 Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
               First : constant Positive := Col;
               Last  : Natural := Col;
            begin
               if Is_Drawable (Cell)
                 and then not Cell.Style.Conceal
                 and then Cell.Kind /= Terminal.Core.Wide_Continuation
               then
                  if Cell.Text.Width = Terminal.Core.Width_One
                    and then Cell.Text.Attachment_Count = 0
                    and then not Style.Is_Block_Cursor (Snapshot, Row, Col)
                  then
                     declare
                        Run_Direction : RM.Text_Run_Direction;
                        Run_Script    : RM.Text_Run_Script;
                     begin
                        Cell_Properties (Cell, Run_Direction, Run_Script);
                        while Last < Snapshot.Cols
                          and then Last - First + 1
                                   < RM.Max_Text_Run_Codepoints
                          and then Cell_Joins_Run
                            (Snapshot, Row, Positive (Last + 1),
                             Cell, Run_Direction, Run_Script)
                        loop
                           Last := Last + 1;
                        end loop;
                     end;
                  end if;

                  Add_Text_Run
                    (R,
                     Snapshot  => Snapshot,
                     Row       => Row,
                     First_Col => First,
                     Last_Col  => Positive (Last),
                     X         =>
                       Float (Origin_X (R) + (First - 1) * R.Text_State.CW),
                     Y         =>
                       Float (Origin_Y (R) + (Row - 1) * R.Text_State.CH),
                     Width     => Float (R.Text_State.CW),
                     Height    => Float (R.Text_State.CH),
                     Color     =>
                       (if Style.Is_Block_Cursor (Snapshot, Row, First)
                        then R.View_State.Color_Theme.Cursor_FG
                        else Style.Foreground (R, Cell)));

                  if R.Frame_State.Text_Run_Count > 0 then
                     case R.Frame_State.Text_Runs (R.Frame_State.Text_Run_Count).Direction is
                        when RM.Direction_Left_To_Right =>
                           Row_Has_LTR := True;
                        when RM.Direction_Right_To_Left =>
                           Row_Has_RTL := True;
                        when RM.Direction_Neutral =>
                           null;
                     end case;
                  end if;

                  if Last + Style.Cell_Column_Span (Cell) > Snapshot.Cols then
                     exit;
                  else
                     Col := Positive (Last + Style.Cell_Column_Span (Cell));
                  end if;
               elsif Col = Snapshot.Cols then
                  exit;
               else
                  Col := Col + 1;
               end if;
            end;
         end loop;

         if Row_Has_RTL then
            Reorder_Mixed_Bidi_Row
              (R,
               First => Row_Run_First,
               Last  => R.Frame_State.Text_Run_Count,
               Right =>
                 Float (Origin_X (R) + Snapshot.Cols * R.Text_State.CW));
         end if;
            declare
               New_Count : constant Natural :=
                 (if R.Frame_State.Text_Run_Count < Row_Run_First
                  then 0
                  else R.Frame_State.Text_Run_Count - Row_Run_First + 1);
            begin
               if New_Count > 0
                 and then
                   (Cached.Runs = null
                    or else Cached.Runs'Length < New_Count)
               then
                  Free_Cached_Runs (Cached.Runs);
                  Cached.Runs := new RM.Text_Run_Array (1 .. New_Count);
               end if;
               if New_Count > 0 then
                  Cached.Runs (1 .. New_Count) :=
                    R.Frame_State.Text_Runs
                      (Row_Run_First .. R.Frame_State.Text_Run_Count);
               end if;
               Cached.Count := New_Count;
               Cached.Text_Valid := True;
            exception
               when Storage_Error =>
                  Cached.Text_Valid := False;
                  R.Frame_State.Frame_Command_Overflowed := True;
                  return;
            end;
         end if;
      end;
   end loop;
   Cache.Last_Cursor := Snapshot.Cursor;
end Build_Text_Runs;
