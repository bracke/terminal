separate (Terminal.App.Renderer)
procedure Add_Image
  (R      : in out Renderer;
   Event  : Terminal.Core.Graphics_Event;
   Snapshot : Terminal.Core.Render_Snapshot)
is
   Event_Header : constant Terminal.App.Graphics.Graphics_Header :=
     Terminal.App.Graphics.Header (Event);
   Header : Terminal.App.Graphics.Graphics_Header := Event_Header;
   Result : Terminal.Core.Kitty_Graphics_Result := (others => <>);
   Number_Object_Before : Image_Object_Access := null;
   Resolved_ID : Terminal.Core.Graphics_ID := 0;
   Placement_Image_ID : Terminal.Core.Graphics_ID := 0;
   Resolved_Geometry : Placement_Geometry := (others => <>);
   Geometry_Checked : Boolean := False;
   Placement_Status : Placement_Store_Status := Placement_Not_Requested;
   Image_Count_Before : constant Natural := Frame_Image_Count (R);
   Placement_Count_Before : constant Natural := R.Kitty_Placement_Count;
   Validation_Error : constant Boolean :=
     Event.Cancelled and then Event.Payload_Length > 0;
   Invalid_Chunk_Transition : constant Boolean :=
     Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Event_Header.Recognized
     and then
       (not Event_Header.Kitty_More_Valid
        or else Event_Header.Kitty_More
        or else
          (Event_Header.Kitty_Transmission in 'f' | 't' | 's'
           and then Event_Header.Kitty_More_Specified));
   Retry_Sensitive : constant Boolean :=
     Event.Pending
     and then Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Event.Sequence /= 0
     and then
       (Event_Header.Recognized
        and then
          (Event_Header.Kitty_More
           or else Event_Header.Kitty_More_Specified
           or else Event_Header.Kitty_ID /= 0
           or else Event_Header.Kitty_Image_Number /= 0
           or else Event_Header.Kitty_Action = 'd'));
   Replay_Guarded : constant Boolean :=
     Retry_Sensitive
     or else
       (Event.Pending
        and then Event.Sequence /= 0
        and then Event.Protocol in
          Terminal.Core.Sixel_Graphics | Terminal.Core.ITerm2_Graphics);
   Track_Result : constant Boolean :=
     Retry_Sensitive
     or else
       (Event.Pending
        and then Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Event.Sequence /= 0
        and then Event_Header.Recognized
        and then not Event_Header.Kitty_More
        and then Event_Header.Kitty_Action in 'T' | 'p' | 'q');


   function Placement_Exists
     (Image_ID : Terminal.Core.Graphics_ID) return Boolean
   is
      Placement : Conventional_Placement_Access;
      Virtual   : Virtual_Placement_Access;
   begin
      if Image_ID = 0 then
         if R.Last_Stored_Image_Order /= 0 then
            Placement := R.Conventional_Placements;
            while Placement /= null loop
               if Placement.Stream_ID = Event.Stream_ID
                 and then Placement.Image_Storage_Order =
                   R.Last_Stored_Image_Order
               then
                  return True;
               end if;
               Placement := Placement.Next;
            end loop;
         end if;
         return Frame_Image_Count (R) > Image_Count_Before;
      elsif Header.Kitty_Virtual_Placement then
         if Header.Kitty_Placement_ID = 0 then
            --  Implicit placements are deliberately not addressable.
            --  A plain placement command must increase the count.  A
            --  transmit-and-display replacement may first remove the old
            --  image's placement, so identify its newly stored object by
            --  storage order in that case.
            if R.Kitty_Placement_Count > Placement_Count_Before then
               return True;
            elsif Header.Kitty_Action /= 'T' then
               return False;
            end if;
            Virtual := R.Virtual_Placements;
            while Virtual /= null loop
               if Virtual.Stream_ID = Event.Stream_ID
                 and then Virtual.Alternate_Screen = Event.Alternate_Screen
                 and then Virtual.Screen_Generation = Event.Screen_Generation
                 and then Virtual.Image_ID = Image_ID
                 and then Virtual.Placement_ID = 0
                 and then Virtual.Image_Storage_Order =
                   R.Last_Stored_Image_Order
               then
                  return True;
               end if;
               Virtual := Virtual.Next;
            end loop;
            return False;
         end if;
         return Find_Virtual_Placement
           (R,
            Event.Stream_ID,
            Event.Alternate_Screen,
            Event.Screen_Generation,
            Image_ID,
            Header.Kitty_Placement_ID) /= null;
      elsif Header.Kitty_Placement_ID /= 0 then
         return Find_Conventional_Placement
           (R,
            Event.Stream_ID,
            Event.Alternate_Screen,
            Event.Screen_Generation,
            Image_ID,
            Header.Kitty_Placement_ID) /= null;
      end if;

      --  As with virtual prototypes, a conventional p=0 placement is a
      --  new, non-addressable object for each command.  A replacement can
      --  leave the total count unchanged after removing the old image;
      --  its storage order distinguishes the replacement from stale data.
      if R.Kitty_Placement_Count > Placement_Count_Before then
         return True;
      elsif Header.Kitty_Action /= 'T' then
         return False;
      end if;
      Placement := R.Conventional_Placements;
      while Placement /= null loop
         if Placement.Stream_ID = Event.Stream_ID
           and then Placement.Alternate_Screen = Event.Alternate_Screen
           and then Placement.Screen_Generation = Event.Screen_Generation
           and then Placement.Image_ID = Image_ID
           and then Placement.Placement_ID = 0
           and then Placement.Image_Storage_Order = R.Last_Stored_Image_Order
         then
            return True;
         end if;
         Placement := Placement.Next;
      end loop;
      return False;
   end Placement_Exists;

   function Validate_Kitty_Command
     return Terminal.Core.Kitty_Graphics_Result_Code
   is
   begin
      if Event.Protocol /= Terminal.Core.Kitty_Graphics
        or else not Header.Recognized
      then
         return Terminal.Core.Kitty_No_Response;
      elsif Header.Kitty_ID > 0 and then Header.Kitty_Image_Number > 0 then
         return Terminal.Core.Kitty_EINVAL;
      elsif Header.Kitty_Action not in 't' | 'T' | 'p' | 'd' | 'f' | 'a' | 'c'
        or else not Header.Kitty_Transmission_Valid
        or else not Header.Kitty_Compression_Valid
      then
         return Terminal.Core.Kitty_ENOTSUP;
      elsif not Header.Kitty_Control_Data_Valid
        or else not Header.Kitty_Action_Controls_Valid
        or else
          (Header.Kitty_Transmission in 'f' | 't' | 's'
           and then
             (not Header.Kitty_Data_Size_Valid
              or else not Header.Kitty_Data_Offset_Valid
              or else Header.Kitty_More_Specified))
      then
         return Terminal.Core.Kitty_EINVAL;
      else
         return Terminal.Core.Kitty_OK;
      end if;
   end Validate_Kitty_Command;

   procedure Finalize_Response is separate;
begin
   if Event.Cancelled and then not Validation_Error then
      if Event.Protocol = Terminal.Core.ITerm2_Graphics then
         Clear_Last_Media_Diagnostics (R);
      end if;
      R.Graphics_Event_Count := R.Graphics_Event_Count + 1;
      R.Kitty_Command_Count := R.Kitty_Command_Count + 1;
      R.Chunk_Cancel_Count := R.Chunk_Cancel_Count + 1;
      return;
   end if;

   if Replay_Guarded
     and then Graphics_Event_Already_Processed (R, Event)
   then
      return;
   end if;

   --  The result cache is fixed-capacity and covers every pane in an app
   --  frame. Refuse unsupported oversized snapshot batches before applying
   --  any persistent graphics side effect.
   if (Replay_Guarded or else Track_Result)
     and then not Can_Remember_Graphics_Event (R, Event)
   then
      R.Graphics_Event_Tracking_Failed := True;
      return;
   end if;

   if Event.Protocol = Terminal.Core.ITerm2_Graphics then
      --  Diagnostics describe the current event, including malformed and
      --  non-inline commands that never enter a decoder. Do this only after
      --  replay detection so a presentation retry retains its result.
      Clear_Last_Media_Diagnostics (R);
   end if;

   R.Graphics_Event_Count := R.Graphics_Event_Count + 1;
   if Event.Protocol = Terminal.Core.Kitty_Graphics then
      R.Kitty_Command_Count := R.Kitty_Command_Count + 1;
   end if;

   if Track_Result and then Header.Recognized then
      Result.Quiet := Natural'Min (Header.Kitty_Quiet, 2);
      Result.Respond :=
        not
          (Header.Kitty_Action = 'T'
           and then Header.Kitty_ID = 0
           and then Header.Kitty_Image_Number = 0);
      Result.Image_ID := Header.Kitty_ID;
      Result.Image_Number := Header.Kitty_Image_Number;
      Result.Has_Image_Number := Header.Kitty_Image_Number /= 0;
      Result.Placement_ID := Header.Kitty_Placement_ID;
      Result.Has_Placement_ID := Header.Kitty_Placement_ID /= 0;

      if Header.Kitty_Image_Number /= 0 then
         Number_Object_Before :=
           Find_Image_Object_By_Number
             (R, Event.Stream_ID, Header.Kitty_Image_Number);
      end if;
      if Header.Kitty_ID /= 0 then
         Resolved_ID := Header.Kitty_ID;
      elsif Header.Kitty_Image_Number /= 0
        and then Header.Kitty_Action not in 't' | 'T'
        and then Number_Object_Before /= null
      then
         Resolved_ID := Number_Object_Before.ID;
      end if;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Validation_Error
   then
      R.Chunk_Cancel_Count := R.Chunk_Cancel_Count + 1;
      Truncate_Image_Commands (R, Image_Count_Before);
      if Track_Result and then Header.Recognized then
         Result.Code := Terminal.Core.Kitty_EINVAL;
         Remember_Processed_Graphics_Event (R, Event, Result);
      end if;
      return;
   end if;

   if Invalid_Chunk_Transition then
      R.Chunk_Cancel_Count := R.Chunk_Cancel_Count + 1;
      Truncate_Image_Commands (R, Image_Count_Before);
      if Track_Result then
         Result.Code := Terminal.Core.Kitty_EINVAL;
         Remember_Processed_Graphics_Event (R, Event, Result);
      end if;
      return;
   end if;

   if Track_Result
     and then Header.Recognized
     and then Header.Kitty_Action = 'q'
   then
      Result.Image_ID := Header.Kitty_ID;
      if Header.Kitty_ID = 0
        or else Header.Kitty_Image_Number /= 0
        or else not Header.Kitty_More_Valid
      then
         Result.Code := Terminal.Core.Kitty_EINVAL;
      elsif not Header.Kitty_Transmission_Valid
        or else not Header.Kitty_Compression_Valid
        or else Header.Kitty_Format not in 8 | 16 | 24 | 32 | 100
          | Terminal.App.Graphics.Kitty_JPEG_Format | Terminal.App.Graphics.Kitty_GIF_Format
      then
         Result.Code := Terminal.Core.Kitty_ENOTSUP;
      elsif not Header.Kitty_Control_Data_Valid
        or else not Header.Kitty_Action_Controls_Valid
      then
         Result.Code := Terminal.Core.Kitty_EINVAL;
      else
         declare
            Query_Header : Terminal.App.Graphics.Graphics_Header := Header;
         begin
            if Query_Header.Kitty_Format = 0 then
               Query_Header.Kitty_Format := 32;
               Query_Header.Raw_Format := 32;
            end if;
            Result.Code :=
              Terminal.App.Image_Ingestion.Validate_Kitty_Query
                (Query_Header,
                 Complete_Event_Text (R, Event),
                 R.Graphics_Access,
                 R.Graphics_Limits.Per_Image_Bytes);
         end;
      end if;
      Remember_Processed_Graphics_Event (R, Event, Result);
      return;
   end if;

   declare
      Validation : constant Terminal.Core.Kitty_Graphics_Result_Code :=
        Validate_Kitty_Command;
   begin
   if Validation not in
     Terminal.Core.Kitty_OK | Terminal.Core.Kitty_No_Response
   then
      if Track_Result then
         Result.Code := Validation;
         Remember_Processed_Graphics_Event (R, Event, Result);
      end if;
      return;
   end if;
   end;

   if Event.Protocol = Terminal.Core.ITerm2_Graphics
     and then Header.Recognized
     and then Header.ITerm2_Control_Data_Valid
     and then not Header.ITerm2_Inline
   then
      declare
         Save_Status : Terminal.App.ITerm2_Files.Save_Status;
         Saved_Name : String
           (1 .. Terminal.App.ITerm2_Files.Max_File_Name_Length);
         Saved_Length : Natural;
      begin
         Terminal.App.ITerm2_Files.Save
           (Complete_Event_Text (R, Event),
            R.ITerm2_Downloads,
            R.Graphics_Limits.Per_Image_Bytes,
            Save_Status,
            Saved_Name,
            Saved_Length);
         pragma Unreferenced (Saved_Name, Saved_Length);
         Result.Code :=
           (case Save_Status is
              when Terminal.App.ITerm2_Files.Save_Ok =>
                Terminal.Core.Kitty_OK,
              when Terminal.App.ITerm2_Files.Save_Too_Large =>
                Terminal.Core.Kitty_ENOSPC,
              when Terminal.App.ITerm2_Files.Save_Allocation_Failed =>
                Terminal.Core.Kitty_ENOMEM,
              when Terminal.App.ITerm2_Files.Save_Disabled =>
                Terminal.Core.Kitty_ENOTSUP,
              when Terminal.App.ITerm2_Files.Save_Invalid_Command
                 | Terminal.App.ITerm2_Files.Save_Invalid_Name
                 | Terminal.App.ITerm2_Files.Save_Invalid_Data =>
                Terminal.Core.Kitty_EINVAL,
              when others => Terminal.Core.Kitty_EBADF);
         if Save_Status =
           Terminal.App.ITerm2_Files.Save_Allocation_Failed
         then
            R.Allocation_Failure_Count := R.Allocation_Failure_Count + 1;
         elsif Save_Status /= Terminal.App.ITerm2_Files.Save_Ok then
            R.Transport_Failure_Count := R.Transport_Failure_Count + 1;
         end if;
         Remember_Processed_Graphics_Event (R, Event, Result);
         return;
      end;
   end if;

   R.Image_Store_Allocation_Failed := False;
   R.Image_Transport_Failed := False;
   R.Last_Animation_Result := Terminal.Core.Kitty_No_Response;
   Apply_Image_Event (R, Event, Snapshot, Placement_Status);
   if R.Kitty_Placement_Count > Placement_Count_Before then
      R.Placement_Create_Count :=
        R.Placement_Create_Count
        + Interfaces.Unsigned_64
            (R.Kitty_Placement_Count - Placement_Count_Before);
   elsif R.Kitty_Placement_Count < Placement_Count_Before then
      R.Placement_Delete_Count :=
        R.Placement_Delete_Count
        + Interfaces.Unsigned_64
            (Placement_Count_Before - R.Kitty_Placement_Count);
   end if;
   if R.Image_Transport_Failed then
      R.Transport_Failure_Count := R.Transport_Failure_Count + 1;
   end if;
   if R.Image_Store_Allocation_Failed then
      R.Allocation_Failure_Count := R.Allocation_Failure_Count + 1;
   end if;
   if Event.Protocol = Terminal.Core.ITerm2_Graphics
     and then Header.Recognized
     and then Header.ITerm2_Control_Data_Valid
     and then Header.ITerm2_Inline
   then
      declare
         Placement : Conventional_Placement_Access :=
           R.Conventional_Placements;
      begin
         while Placement /= null loop
            exit when Placement.Stream_ID = Event.Stream_ID
              and then Placement.Protocol = RM.Image_ITerm2
              and then Placement.Image_Storage_Order =
                R.Last_Stored_Image_Order;
            Placement := Placement.Next;
         end loop;
         if Placement /= null and then R.Last_Stored_Image_Order /= 0 then
            --  iTerm2 emits no protocol reply, but an internal success
            --  result commits its default cursor movement atomically with
            --  the decoded image. Complete_Graphics_Event serializes
            --  replies only for Kitty events.
            Result.Code := Terminal.Core.Kitty_OK;
            if not Header.ITerm2_Do_Not_Move_Cursor then
               Result.Move_Cursor := True;
               Result.Cursor_To_Line_Start := True;
               Result.Placement_Columns := 1;
               Result.Placement_Rows := Placement.Rows;
            end if;
         end if;
      end;
   end if;
   if Header.Recognized and then Header.Kitty_Action in 'T' | 'p' then
      Placement_Image_ID := Header.Kitty_ID;
      if Placement_Image_ID = 0
        and then Header.Kitty_Image_Number /= 0
      then
         declare
            Stored : constant Image_Object_Access :=
              Find_Image_Object_By_Number
                (R, Event.Stream_ID, Header.Kitty_Image_Number);
         begin
            if Stored /= null then
               Placement_Image_ID := Stored.ID;
            end if;
         end;
      end if;
      if Placement_Image_ID /= 0 then
         declare
            Object : constant Image_Object_Access :=
              Find_Image_Object
                (R, Event.Stream_ID, Placement_Image_ID);
         begin
            if Object /= null then
               Resolved_Geometry :=
                 Resolve_Placement_Geometry (R, Object, Header);
               Geometry_Checked := True;
            end if;
         end;
      elsif Header.Kitty_Action = 'T'
        and then R.Last_Stored_Image_Order /= 0
      then
         declare
            Object : constant Image_Object_Access :=
              Find_Image_Object_By_Storage_Order
                (R, Event.Stream_ID, R.Last_Stored_Image_Order);
         begin
            if Object /= null then
               Resolved_Geometry :=
                 Resolve_Placement_Geometry (R, Object, Header);
               Geometry_Checked := True;
            end if;
         end;
      elsif Header.Kitty_Action = 'T'
        and then Frame_Image_Commands (R) /= null
        and then Frame_Image_Count (R) > Image_Count_Before
      then
         Resolved_Geometry :=
           Resolve_Placement_Geometry
             (R,
              FIS.Element (R.Frame_Images, Frame_Image_Count (R)).Pixel_Width,
              FIS.Element (R.Frame_Images, Frame_Image_Count (R)).Pixel_Height,
              Header);
         Geometry_Checked := True;
      end if;
   end if;
   Finalize_Response;
end Add_Image;
