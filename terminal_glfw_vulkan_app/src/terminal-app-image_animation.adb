with Ada.Real_Time;
with Ada.Exceptions;
with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Image_Store.Frames;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Image_Store.Playback_State;
with Terminal.App.Cleanup_Diagnostics;

package body Terminal.App.Image_Animation is
   package Store renames Terminal.App.Image_Store;
   package Playback renames Terminal.App.Image_Store.Playback_State;
   package Frames renames Terminal.App.Image_Store.Frames;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Store.Animation_Playback_State;
   use type Store.Image_Object_Access;
   use type Store.Image_Frame_Access;

   Minimum_Zero_Gap_Delay_MS : constant := 10;

   function Frame_Delay (Gap_MS : Integer) return Ada.Real_Time.Time_Span is
     (Ada.Real_Time.Milliseconds
        (if Gap_MS < 0
         then 0
         elsif Gap_MS = 0
         then Minimum_Zero_Gap_Delay_MS
         else Gap_MS));

   function Resume_Delay (Gap_MS : Integer) return Ada.Real_Time.Time_Span is
     (Ada.Real_Time.Milliseconds
        (if Gap_MS <= 0
         then Minimum_Zero_Gap_Delay_MS
         else Gap_MS));

   function Apply_Control
     (Container : in out Store.Store;
      Object : Store.Image_Object_Access;
      Control : Animation_Control) return Control_Result
   is
      State : Playback.State;
   begin
      if Object = null then
         return Control_Not_Found;
      elsif Control.Frame_Number > 0
        and then not Frames.Exists (Object, Control.Frame_Number)
      then
         return Control_Not_Found;
      elsif Control.Start_Frame > 0
        and then not Frames.Exists (Object, Control.Start_Frame)
      then
         return Control_Not_Found;
      end if;

      State := Playback.Value (Object.all);

      if Control.Frame_Number > 0
        and then Control.Frame_Gap /= 0
      then
         if Control.Frame_Number = 1 then
            State.Root_Gap_MS := Control.Frame_Gap;
         elsif not Frames.Set_Gap
           (Container,
            Object,
            Positive (Control.Frame_Number),
            Control.Frame_Gap)
         then
            return Control_Not_Found;
         end if;
      end if;
      if Control.Start_Frame > 0 then
         State.Current_Frame := Positive (Control.Start_Frame);
         State.Deadline_Set := False;
      end if;
      if Control.Loop_Count > 0 then
         State.Loop_Count := Positive (Control.Loop_Count);
         State.Loops_Completed := 0;
      end if;
      case Control.State is
         when Stopped =>
            State.Mode := Store.Animation_Stopped;
            State.Loops_Completed := 0;
            State.Deadline_Set := False;
         when Loading =>
            State.Mode := Store.Animation_Loading;
            State.Deadline_Set := False;
         when Running =>
            State.Mode := Store.Animation_Running;
            State.Deadline_Set := False;
         when Unchanged =>
            null;
      end case;
      Playback.Replace (Object, State);
      return Control_Ok;
   exception
      when Constraint_Error =>
         return Control_Invalid;
   end Apply_Control;

   procedure Adopt_Decoded_Frames
     (Container : in out Store.Store;
      Object    : Store.Image_Object_Access;
      Media     : Terminal.App.Image_Media.Decoded_Image;
      Control   : in out Store.Allocation_Control;
      Success   : out Boolean)
   is
      Head : Store.Image_Frame_Access := null;
      Tail : Store.Image_Frame_Access := null;

      procedure Release is
      begin
         Frames.Release_Unowned (Head);
         Tail := null;
      end Release;
   begin
      Success := False;
      if Object = null
        or else not Media.Has_Bytes
        or else Media.Frame_Count <= 1
        or else Media.Frame_Bytes = 0
        or else Media.Frame_Count >
          Media.Byte_Length / Media.Frame_Bytes
      then
         return;
      end if;
      for Number in 2 .. Media.Frame_Count loop
         declare
            Data : Terminal.App.Owned_Image_Data.Owner;
            Frame : Store.Image_Frame_Access;
            procedure Copy_Frame
              (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
            begin
               Media.Copy_Frame (Number, Bytes);
            end Copy_Frame;
         begin
            if not Store.Allocation_Allowed (Control) then
               raise Storage_Error;
            end if;
            Terminal.App.Owned_Image_Data.Allocate
              (Data, Media.Frame_Bytes);
            Terminal.App.Owned_Image_Data.Modify (Data, Copy_Frame'Access);
            if not Store.Allocation_Allowed (Control) then
               raise Storage_Error;
            end if;
            Frames.Create
              (Number,
               Integer (Media.Delay_MS (Number)),
               0,
               Data,
               Frame);
            Frames.Append_Unowned (Head, Tail, Frame);
         exception
            when others =>
               begin
                  Frames.Release_Unowned (Frame);
               exception
                  when E : others =>
                     Terminal.App.Cleanup_Diagnostics.Note_Failure
                       (Terminal.App.Cleanup_Diagnostics.Image_Install,
                        E,
                        "release unlinked animation frame");
               end;
               raise;
         end;
      end loop;
      Frames.Adopt (Container, Object, Head);
      Tail := null;
      Success := True;
   exception
      when Storage_Error =>
         Release;
         Success := False;
      when others =>
         Release;
         raise;
   end Adopt_Decoded_Frames;

   function Advance
     (Object : Store.Image_Object_Access;
      Now    : Ada.Real_Time.Time) return Natural
   is
      Result : Natural := 0;
   begin
      if Object = null or else Frames.Count (Object) <= 1 then
         return 0;
      end if;
      declare
         Count : constant Positive := Positive (Frames.Count (Object));
         State : Playback.State := Playback.Value (Object.all);
         type Gap_Array is array (Positive range <>) of Integer;
         Gaps : Gap_Array (1 .. Count) := (others => 0);
         Borrow : Store.Data_Borrow;
         Position : Frames.Cursor;
         Cycle_Span : Ada.Real_Time.Time_Span :=
           Ada.Real_Time.Time_Span_Zero;

         procedure Advance_At_Deadline is
         begin
            if State.Current_Frame < Count then
               State.Current_Frame := State.Current_Frame + 1;
            elsif State.Mode = Store.Animation_Loading then
               State.Deadline_Set := False;
               return;
            elsif State.Loop_Count /= 1
              and then State.Loops_Completed >= State.Loop_Count - 1
            then
               State.Mode := Store.Animation_Stopped;
               State.Loops_Completed := 0;
               State.Deadline_Set := False;
               return;
            else
               State.Current_Frame := 1;
               --  Loop_Count = 1 is the internal infinite-loop sentinel.  Its
               --  completed-loop count has no semantic value and must not grow
               --  until Natural overflows during long-running animations.
               if State.Loop_Count /= 1 then
                  State.Loops_Completed := State.Loops_Completed + 1;
               end if;
            end if;
            Result := Result + 1;
            State.Next_Frame_At :=
              State.Next_Frame_At + Frame_Delay (Gaps (State.Current_Frame));
         end Advance_At_Deadline;
      begin
         if State.Mode = Store.Animation_Stopped then
            return 0;
         elsif State.Deadline_Set and then Now < State.Next_Frame_At then
            --  The common not-yet-due path does not scan every frame.
            return 0;
         end if;
         Store.Borrow (Borrow, Object);
         Position := Frames.First (Borrow);
         while Frames.Has_Element (Position) loop
            declare
               Info : constant Frames.Frame_Descriptor :=
                 Frames.Descriptor (Borrow, Position);
            begin
               if Info.Number <= Count then
                  Gaps (Info.Number) := Info.Gap_MS;
               end if;
            end;
            Frames.Next (Borrow, Position);
         end loop;
         for Gap of Gaps loop
            Cycle_Span := Cycle_Span + Frame_Delay (Gap);
         end loop;

         if not State.Deadline_Set then
            State.Next_Frame_At :=
              Now + Frame_Delay (Gaps (State.Current_Frame));
            State.Deadline_Set := True;
         end if;

         for Step in 1 .. Count loop
            exit when State.Mode = Store.Animation_Stopped
              or else not State.Deadline_Set
              or else Now < State.Next_Frame_At;
            Advance_At_Deadline;
         end loop;

         if State.Mode /= Store.Animation_Stopped
           and then State.Deadline_Set
           and then Now >= State.Next_Frame_At
           and then Gaps (State.Current_Frame) >= 0
         then
            --  The bounded loop above handles at most one visible cycle.  A
            --  whole-cycle calculation then advances elapsed loop accounting
            --  and the deadline without walking the frame list repeatedly.
            if Cycle_Span > Ada.Real_Time.Time_Span_Zero then
               declare
                  function Cycles_Due return Natural is
                  begin
                     return
                       Natural
                         ((Now - State.Next_Frame_At) /
                            Cycle_Span) + 1;
                  exception
                     when Constraint_Error =>
                        return Natural'Last;
                  end Cycles_Due;

                  Cycles_Needed : constant Natural := Cycles_Due;
                  Remaining_Wraps : constant Natural :=
                    (if State.Loop_Count = 1
                     then Natural'Last
                     elsif State.Loops_Completed >= State.Loop_Count - 1
                     then 0
                     else State.Loop_Count - 1 - State.Loops_Completed);
                  Cycles_To_Skip : constant Natural :=
                    (if State.Loop_Count = 1
                     then Cycles_Needed
                     else Natural'Min
                       (Cycles_Needed, Remaining_Wraps));
                  New_Deadline : Ada.Real_Time.Time :=
                    State.Next_Frame_At;
                  Deadline_Valid : Boolean := True;
               begin
                  if Cycles_To_Skip > 0 then
                     begin
                        New_Deadline :=
                          State.Next_Frame_At
                          + Integer (Cycles_To_Skip) * Cycle_Span;
                     exception
                        when Constraint_Error =>
                           Deadline_Valid := False;
                     end;

                     if Deadline_Valid then
                        if State.Loop_Count /= 1 then
                           State.Loops_Completed :=
                             State.Loops_Completed + Cycles_To_Skip;
                        end if;
                        State.Next_Frame_At := New_Deadline;
                     else
                        State.Next_Frame_At :=
                          Now + Resume_Delay (Gaps (State.Current_Frame));
                     end if;
                  end if;

                  if Deadline_Valid
                    and then State.Loop_Count /= 1
                    and then Cycles_Needed > Remaining_Wraps
                  then
                     --  No complete loop remains to skip.  Walk only the
                     --  terminal partial cycle so the final frame retains its
                     --  own delay instead of being selected prematurely.
                     for Step in 1 .. Count loop
                        exit when State.Mode = Store.Animation_Stopped
                          or else not State.Deadline_Set
                          or else Now < State.Next_Frame_At;
                        Advance_At_Deadline;
                     end loop;
                  end if;
               end;
            else
               State.Next_Frame_At :=
                 (if State.Loop_Count = 1
                  then Now + Resume_Delay (Gaps (State.Current_Frame))
                  else Now);
            end if;
         end if;
         Playback.Replace (Object, State);
         return Result;
      end;
   end Advance;
end Terminal.App.Image_Animation;
