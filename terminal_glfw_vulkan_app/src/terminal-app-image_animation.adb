with Ada.Real_Time;
with Ada.Unchecked_Deallocation;
with Terminal.Common.Bytes;
with Terminal.App.Render_Model;

package body Terminal.App.Image_Animation is
   package Store renames Terminal.App.Image_Store;
   use type Ada.Real_Time.Time;
   use type Store.Animation_Playback_State;
   use type Store.Image_Object_Access;
   use type Store.Image_Frame_Access;
   use type Terminal.App.Render_Model.Image_Data_Access;

   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Render_Model.Image_Data_Access);

   function Apply_Control
     (Object : Store.Image_Object_Access;
      Control : Animation_Control) return Control_Result
   is
   begin
      if Object = null then
         return Control_Not_Found;
      elsif Control.Frame_Number > 0
        and then not Store.Frame_Exists (Object, Control.Frame_Number)
      then
         return Control_Not_Found;
      elsif Control.Start_Frame > 0
        and then not Store.Frame_Exists (Object, Control.Start_Frame)
      then
         return Control_Not_Found;
      end if;

      if Control.Frame_Number > 0
        and then Control.Frame_Gap /= 0
        and then not Store.Set_Frame_Gap
          (Object,
           Positive (Control.Frame_Number),
           Control.Frame_Gap)
      then
         return Control_Not_Found;
      end if;
      if Control.Start_Frame > 0 then
         Store.Set_Current_Frame
           (Object, Positive (Control.Start_Frame));
         Store.Set_Deadline (Object, False);
      end if;
      if Control.Loop_Count > 0 then
         Store.Set_Loop_Count
           (Object, Positive (Control.Loop_Count));
         Store.Set_Loops_Completed (Object, 0);
      end if;
      case Control.State is
         when Stopped =>
            Store.Set_Playback (Object, Store.Animation_Stopped);
            Store.Set_Loops_Completed (Object, 0);
            Store.Set_Deadline (Object, False);
         when Loading =>
            Store.Set_Playback (Object, Store.Animation_Loading);
            Store.Set_Deadline (Object, False);
         when Running =>
            Store.Set_Playback (Object, Store.Animation_Running);
            Store.Set_Deadline (Object, False);
         when Unchanged =>
            null;
      end case;
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
         Store.Release_Unowned_Frames (Head);
         Tail := null;
      end Release;
   begin
      Success := False;
      if Object = null
        or else Media.Bytes = null
        or else Media.Frame_Count <= 1
        or else Media.Frame_Bytes = 0
        or else Media.Frame_Count >
          Media.Bytes'Length / Media.Frame_Bytes
      then
         return;
      end if;
      for Number in 2 .. Media.Frame_Count loop
         declare
            Data : Terminal.App.Render_Model.Image_Data_Access := null;
            First : constant Positive :=
              Media.Bytes'First + (Number - 1) * Media.Frame_Bytes;
            Frame : Store.Image_Frame_Access;
         begin
            if not Store.Allocation_Allowed (Control) then
               raise Storage_Error;
            end if;
            Data := new Terminal.Common.Bytes.Byte_Array (1 .. Media.Frame_Bytes);
            Data.all := Media.Bytes (First .. First + Media.Frame_Bytes - 1);
            if not Store.Allocation_Allowed (Control) then
               raise Storage_Error;
            end if;
            Store.Create_Frame
              (Number,
               Integer (Media.Delays_MS (Number)),
               0,
               Data,
               Frame);
            Store.Append_Unowned_Frame (Head, Tail, Frame);
         exception
            when others =>
               Free_Image_Data (Data);
               begin
                  Store.Release_Unowned_Frames (Frame);
               exception
                  when others => null;
               end;
               raise;
         end;
      end loop;
      Store.Adopt_Frames (Container, Object, Head);
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
      if Object = null
        or else Object.Playback = Store.Animation_Stopped
        or else Store.Frame_Count_Of (Object) <= 1
      then
         return 0;
      end if;

      if not Object.Deadline_Set then
         Store.Set_Next_Frame_At
           (Object,
            Now
            + Ada.Real_Time.Milliseconds
                (Integer'Max
                   (0, Store.Frame_Gap (Object, Object.Current_Frame))));
         Store.Set_Deadline (Object, True);
      end if;

      for Step in 1 .. Store.Frame_Count_Of (Object) loop
         exit when Object.Playback = Store.Animation_Stopped
           or else not Object.Deadline_Set
           or else Now < Object.Next_Frame_At;
         if Object.Current_Frame < Store.Frame_Count_Of (Object) then
            Store.Set_Current_Frame (Object, Object.Current_Frame + 1);
         elsif Object.Playback = Store.Animation_Loading then
            Store.Set_Deadline (Object, False);
            exit;
         elsif Object.Loop_Count /= 1
           and then Object.Loops_Completed >= Object.Loop_Count - 1
         then
            Store.Set_Playback (Object, Store.Animation_Stopped);
            Store.Set_Loops_Completed (Object, 0);
            Store.Set_Deadline (Object, False);
            exit;
         else
            Store.Set_Current_Frame (Object, 1);
            --  Loop_Count = 1 is the internal infinite-loop sentinel.  Its
            --  completed-loop count has no semantic value and must not grow
            --  until Natural overflows during long-running animations.
            if Object.Loop_Count /= 1 then
               Store.Set_Loops_Completed
                 (Object, Object.Loops_Completed + 1);
            end if;
         end if;
         Result := Result + 1;
         Store.Set_Next_Frame_At
           (Object,
            Object.Next_Frame_At
            + Ada.Real_Time.Milliseconds
                (Integer'Max
                   (0, Store.Frame_Gap (Object, Object.Current_Frame))));
      end loop;
      return Result;
   end Advance;
end Terminal.App.Image_Animation;
