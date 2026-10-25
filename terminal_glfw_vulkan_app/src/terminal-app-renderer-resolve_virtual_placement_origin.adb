separate (Terminal.App.Renderer)
function Resolve_Virtual_Placement_Origin
  (R            : Renderer;
   Snapshot     : Terminal.Core.Render_Snapshot;
   Image_ID     : Terminal.Core.Graphics_ID;
   Placement_ID : Terminal.Core.Graphics_ID;
   Row           : out Integer;
   Col           : out Integer;
   Use_Index     : Boolean := False) return Boolean
is
   Placement : Virtual_Placement_Access := null;
   Found : Boolean := False;
begin
   Row := 0;
   Col := 0;
   if Use_Index then
      return Terminal.App.Placeholder_Index.Find_Origin
        (R.Placement_Index,
         Snapshot.Graphics_Stream,
         Snapshot.Alternate_Screen,
         Snapshot.Screen_Generation,
         Image_ID,
         Placement_ID,
         Row,
         Col);
   end if;
   Placement :=
     Find_Virtual_Placement
       (R,
        Snapshot.Graphics_Stream,
        Snapshot.Alternate_Screen,
        Snapshot.Screen_Generation,
        Image_ID,
        Placement_ID);
   if Placement = null then
      return False;
   end if;

   for Cell_Row in 1 .. Snapshot.Rows loop
      for Cell_Col in 1 .. Snapshot.Cols loop
         declare
            Cell : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (Snapshot, Cell_Row, Cell_Col);
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
