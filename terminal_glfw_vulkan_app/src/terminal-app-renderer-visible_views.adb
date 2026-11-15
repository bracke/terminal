with Terminal.App.Splits;
with Terminal.Core;

package body Terminal.App.Renderer.Visible_Views is
   procedure Set_All
     (R : in out Renderer; Snapshots : Snapshot_Array)
   is
      New_Views : Graphics_View_Identity_Array := (others => <>);
      New_Count : constant Terminal.App.Splits.Pane_Count :=
        Terminal.App.Splits.Pane_Count
          (Natural'Min (Snapshots'Length, Terminal.App.Splits.Max_Panes));
      Changed : Boolean := New_Count /= R.Graphics_State.Visible_View_Count;
   begin
      if New_Count > 0 then
         for Offset in 0 .. Natural (New_Count) - 1 loop
            declare
               Target : constant Terminal.App.Splits.Pane_Index :=
                 Terminal.App.Splits.Pane_Index (Offset + 1);
            begin
               New_Views (Target) :=
                 (Stream_ID =>
                    Snapshots (Snapshots'First + Offset).Graphics_Stream,
                  Alternate_Screen =>
                    Snapshots (Snapshots'First + Offset).Alternate_Screen,
                  Screen_Generation =>
                    Snapshots (Snapshots'First + Offset).Screen_Generation);
               Changed := Changed
                 or else New_Views (Target) /=
                   R.Graphics_State.Visible_Views (Target);
            end;
         end loop;
      end if;
      if Changed then
         R.Graphics_State.Visible_Views := New_Views;
         R.Graphics_State.Visible_View_Count := New_Count;
         R.Graphics_State.Animation_Schedule_Valid := False;
      end if;
   end Set_All;

   procedure Set_One
     (R : in out Renderer; Snapshot : Terminal.Core.Render_Snapshot)
   is
      Changed : constant Boolean :=
        R.Graphics_State.Visible_View_Count /= 1
        or else R.Graphics_State.Visible_Views (1) /=
          (Stream_ID         => Snapshot.Graphics_Stream,
           Alternate_Screen  => Snapshot.Alternate_Screen,
           Screen_Generation => Snapshot.Screen_Generation);
   begin
      if Changed then
         R.Graphics_State.Visible_Views := (others => <>);
         R.Graphics_State.Visible_Views (1) :=
           (Stream_ID         => Snapshot.Graphics_Stream,
            Alternate_Screen  => Snapshot.Alternate_Screen,
            Screen_Generation => Snapshot.Screen_Generation);
         R.Graphics_State.Visible_View_Count := 1;
         R.Graphics_State.Animation_Schedule_Valid := False;
      end if;
   end Set_One;
end Terminal.App.Renderer.Visible_Views;
