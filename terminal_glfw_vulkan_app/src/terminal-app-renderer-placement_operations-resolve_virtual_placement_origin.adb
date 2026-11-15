separate (Terminal.App.Renderer.Placement_Operations)
function Resolve_Virtual_Placement_Origin
  (R            : Renderer;
   Snapshot     : Terminal.Core.Render_Snapshot;
   Image_ID     : Terminal.Core.Graphics_ID;
   Placement_ID : Terminal.Core.Graphics_ID;
   Row           : out Integer;
   Col           : out Integer;
   Use_Index     : Boolean := False) return Boolean
is
   Placement : Placements_State.Virtual_Placement_Value;
   Found : Boolean := False;
begin
   Row := 0;
   Col := 0;
   if Use_Index then
      return Terminal.App.Placeholder_Index.Find_Origin
        (R.Frame_State.Placement_Index,
         Snapshot.Graphics_Stream,
         Snapshot.Alternate_Screen,
         Snapshot.Screen_Generation,
         Image_ID,
         Placement_ID,
         Row,
         Col);
   end if;
   Placement :=
     Placements_State.Find_Virtual_Placement
       (R,
        Snapshot.Graphics_Stream,
        Snapshot.Alternate_Screen,
        Snapshot.Screen_Generation,
        Image_ID,
        Placement_ID);
   if not Placement.Exists then
      return False;
   end if;

   for Cell_Row in 1 .. Snapshot.Rows loop
      for Cell_Col in 1 .. Snapshot.Cols loop
         declare
            Cell : constant Terminal.Core.Cell_Content :=
              Terminal.Core.Cell_Content_At (Snapshot, Cell_Row, Cell_Col);
         begin
            if Cell.Image.Is_Placeholder
              and then Cell.Image.Image_ID_Valid
              and then Cell.Image.Image_ID = Image_ID
              and then Cell.Image.Placement_ID = Placement_ID
            then
               if not Found then
                  Row := Cell_Row;
                  Col := Cell_Col;
                  Found := True;
               else
                  Row := Integer'Min (Row, Cell_Row);
                  Col := Integer'Min (Col, Cell_Col);
               end if;
            end if;
         end;
      end loop;
   end loop;
   return Found;
end Resolve_Virtual_Placement_Origin;
