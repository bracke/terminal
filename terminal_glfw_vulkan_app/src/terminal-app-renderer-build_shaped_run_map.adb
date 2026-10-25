separate (Terminal.App.Renderer)
procedure Build_Shaped_Run_Map
  (R         : in out Renderer;
   Snapshot  : Terminal.Core.Render_Snapshot;
   First_Run : Positive)
is
   Cell_Count : constant Natural := Snapshot.Rows * Snapshot.Cols;
begin
   if R.Shaped_Run_Map = null
     or else R.Shaped_Run_Map'Length < Cell_Count
   then
      return;
   end if;

   R.Shaped_Run_Map (1 .. Cell_Count) := (others => <>);
   for I in First_Run .. R.Text_Run_Count loop
      if Is_Shaped_Draw_Run (R.Text_Runs (I)) then
         declare
            Run : RM.Text_Run_Command renames R.Text_Runs (I);
            Row_Number : constant Integer :=
              Integer
                ((Run.Y - Float (Origin_Y (R))) / Float (R.CH)) + 1;
            Start_Column : constant Integer :=
              Integer
                ((Run.X - Float (Origin_X (R))) / Float (R.CW)) + 1;
         begin
            if Row_Number in 1 .. Snapshot.Rows
              and then Start_Column in 1 .. Snapshot.Cols
            then
               declare
                  Row : constant Positive := Positive (Row_Number);
                  First_Col : constant Positive := Positive (Start_Column);
                  Last_Col : constant Positive := Positive'Min
                    (Snapshot.Cols, First_Col + Run.Cell_Span - 1);
               begin
                  for Col in First_Col .. Last_Col loop
                     R.Shaped_Run_Map
                       ((Row - 1) * Snapshot.Cols + Col) :=
                         (Run_Index   => I,
                          Starts_Here => Col = First_Col);
                  end loop;
               end;
            end if;
         end;
      end if;
   end loop;
end Build_Shaped_Run_Map;
