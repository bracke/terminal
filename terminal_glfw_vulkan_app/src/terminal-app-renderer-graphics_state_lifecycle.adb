with Ada.Unchecked_Deallocation;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Image_Store;
with Terminal.App.Renderer.Event_Tracking;
with Terminal.App.Renderer.Frame_Lifecycle;
with Terminal.App.Renderer.Placement_State;
with Terminal.App.Text_Shaper;
with Textrender;

package body Terminal.App.Renderer.Graphics_State_Lifecycle is
   use type Sixel_Palette_Entry_Access;

   procedure Free_Sixel_Palette_Entry is new Ada.Unchecked_Deallocation
     (Sixel_Palette_Entry, Sixel_Palette_Entry_Access);

   procedure Release (Value : in out Sixel_Palette_Entry_Access) is
   begin
      Free_Sixel_Palette_Entry (Value);
   end Release;

   procedure Release (Object : in out Renderer_Graphics_State) is
      Palette : Sixel_Palette_Entry_Access := Object.Resources.Sixel_Palettes;
      Failed : Boolean := False;
   begin
      if Object.Cleanup_Complete then
         return;
      end if;
      begin
         Event_Tracking.Release (Object);
      exception
         when E : others =>
            Failed := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Renderer_State,
               E,
               "release processed graphics events");
      end;
      begin
         while Palette /= null loop
            declare
               Next : constant Sixel_Palette_Entry_Access := Palette.Next;
            begin
               Free_Sixel_Palette_Entry (Palette);
               Palette := Next;
            end;
         end loop;
         Object.Resources.Sixel_Palettes := null;
      exception
         when E : others =>
            Object.Resources.Sixel_Palettes := Palette;
            Failed := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Renderer_State,
               E,
               "release sixel palettes");
      end;
      begin
         Placement_State.Release_All (Object);
      exception
         when E : others =>
            Failed := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Renderer_State,
               E,
               "release image placements");
      end;
      begin
         Terminal.App.Image_Store.Release_All
           (Object.Resources.Image_Objects);
      exception
         when E : others =>
            Failed := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Renderer_State,
               E,
               "release image objects");
      end;
      if Failed then
         raise Program_Error with "renderer graphics-state cleanup failed";
      end if;
      Object.Cleanup_Complete := True;
   end Release;

   procedure Finalize_Renderer (R : in out Renderer) is
      Cleanup_Failed : Boolean := False;

      procedure Release_Frame_Safely is
      begin
         Frame_Lifecycle.Release (R);
      exception
         when E : others =>
            Cleanup_Failed := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Renderer_State,
               E,
               "release renderer frame");
      end Release_Frame_Safely;

      procedure Release_Events_Safely is
      begin
         Commit_Graphics_Events (R);
      exception
         when E : others =>
            Cleanup_Failed := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Renderer_State,
               E,
               "commit renderer events");
      end Release_Events_Safely;

      procedure Release_Text_Safely is
      begin
         begin
            Textrender.Reset (R.Text_State.Text);
         exception
            when E : others =>
               Cleanup_Failed := True;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Renderer_State,
                  E,
                  "reset text renderer");
         end;
         begin
            Terminal.App.Text_Shaper.Reset (R.Text_State.Shaper);
         exception
            when E : others =>
               Cleanup_Failed := True;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Renderer_State,
                  E,
                  "reset text shaper");
         end;
      end Release_Text_Safely;

      procedure Release_Graphics_State_Safely is
      begin
         Release (R.Graphics_State);
      exception
         when E : others =>
            Cleanup_Failed := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Renderer_State,
               E,
               "release graphics state");
      end Release_Graphics_State_Safely;
   begin
      if not R.Lifecycle.Needs_Finalization then
         R.Lifecycle.Closed := True;
         return;
      end if;
      --  Keep finalization armed until each independent resource group has
      --  been released, so an explicit retry can finish partial cleanup.
      R.Lifecycle.Closed := True;
      R.Lifecycle.Initialized := False;
      Release_Frame_Safely;
      Release_Events_Safely;
      Release_Graphics_State_Safely;
      Release_Text_Safely;
      if not Cleanup_Failed then
         R.Lifecycle.Needs_Finalization := False;
      end if;
      R.Lifecycle.Has_Context := False;
      R.Text_State.Text_Loaded := False;
      Frame_Lifecycle.Reset_Counters (R);
      R.Frame_State.Target_Frame_Width := 0;
      R.Frame_State.Target_Frame_Height := 0;
      R.View_State.Hovered_Link := (others => <>);
      R.Text_State.Atlas_Dirty := False;
      R.Text_State.Colour_Sheet_Dirty := False;
      R.Lifecycle.Last_Render_Status := Not_Initialized;
   exception
      when E : others =>
         --  A controlled finalizer must not mask an exception already being
         --  propagated by scope unwinding.
         R.Lifecycle.Closed := True;
         R.Lifecycle.Initialized := False;
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Renderer_State,
            E,
            "finalize renderer state");
   end Finalize_Renderer;
end Terminal.App.Renderer.Graphics_State_Lifecycle;
