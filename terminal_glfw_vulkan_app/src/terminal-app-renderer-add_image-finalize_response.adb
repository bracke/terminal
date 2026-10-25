separate (Terminal.App.Renderer.Add_Image)
   procedure Finalize_Response is
   begin
      if Track_Result then
         if Header.Recognized and then not Event_Header.Kitty_More then
            if Header.Kitty_Action in 'f' | 'a' | 'c' then
               Result.Image_ID := Resolved_ID;
               Result.Code :=
                 (if R.Image_Transport_Failed
                  then Terminal.Core.Kitty_EBADF
                  elsif R.Image_Store_Allocation_Failed
                  then Terminal.Core.Kitty_ENOMEM
                  elsif R.Last_Animation_Result = Terminal.Core.Kitty_No_Response
                  then Terminal.Core.Kitty_EINVAL
                  else R.Last_Animation_Result);
            elsif Header.Kitty_Action = 'p' then
               Result.Image_ID := Resolved_ID;
               if Placement_Status = Placement_Parent_Missing then
                  Result.Code := Terminal.Core.Kitty_ENOPARENT;
               elsif Placement_Status = Placement_Cycle then
                  Result.Code := Terminal.Core.Kitty_ECYCLE;
               elsif Placement_Status = Placement_Too_Deep then
                  Result.Code := Terminal.Core.Kitty_ETOODEEP;
               elsif Placement_Status = Placement_No_Space then
                  Result.Code := Terminal.Core.Kitty_ENOMEM;
               elsif Resolved_ID = 0
                 or else Find_Image_Object
                   (R, Event.Stream_ID, Resolved_ID) = null
               then
                  Result.Code := Terminal.Core.Kitty_ENOENT;
               elsif Header.Kitty_Virtual_Placement
                 and then Header.Kitty_Parent_ID /= 0
               then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               elsif Header.Kitty_Parent_ID /= 0 then
                  declare
                     Relative_Status : constant Relative_Placement_Status :=
                       Validate_Relative_Placement
                         (R,
                          Event.Stream_ID,
                          Event.Alternate_Screen,
                          Event.Screen_Generation,
                          Resolved_ID,
                          Header.Kitty_Placement_ID,
                          Header.Kitty_Parent_ID,
                          Header.Kitty_Parent_Placement_ID);
                  begin
                     Result.Code :=
                       (case Relative_Status is
                           when Relative_Valid => Terminal.Core.Kitty_OK,
                           when Relative_Parent_Missing =>
                             Terminal.Core.Kitty_ENOPARENT,
                           when Relative_Cycle => Terminal.Core.Kitty_ECYCLE,
                           when Relative_Too_Deep =>
                             Terminal.Core.Kitty_ETOODEEP);
                  end;
               elsif Placement_Status = Placement_Rejected then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               else
                  Result.Code := Terminal.Core.Kitty_OK;
               end if;
            elsif Header.Kitty_Action in 't' | 'T' then
               if Placement_Status = Placement_Parent_Missing then
                  Result.Code := Terminal.Core.Kitty_ENOPARENT;
               elsif Placement_Status = Placement_Cycle then
                  Result.Code := Terminal.Core.Kitty_ECYCLE;
               elsif Placement_Status = Placement_Too_Deep then
                  Result.Code := Terminal.Core.Kitty_ETOODEEP;
               elsif Placement_Status = Placement_No_Space then
                  Result.Code := Terminal.Core.Kitty_ENOMEM;
               elsif Placement_Status = Placement_Rejected then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               elsif Header.Kitty_Image_Number /= 0 then
                  declare
                     Stored : constant Image_Object_Access :=
                       Find_Image_Object_By_Number
                         (R, Event.Stream_ID, Header.Kitty_Image_Number);
                  begin
                     if Stored = null
                       or else Stored = Number_Object_Before
                     then
                        Result.Code :=
                          (if R.Image_Store_Allocation_Failed
                           then Terminal.Core.Kitty_ENOMEM
                           elsif R.Image_Transport_Failed
                           then Terminal.Core.Kitty_EBADF
                           else Terminal.Core.Kitty_EINVAL);
                     else
                        Result.Image_ID := Stored.ID;
                        Result.Code := Terminal.Core.Kitty_OK;
                     end if;
                  end;
               elsif Header.Kitty_ID /= 0 then
                  Result.Code :=
                    (if R.Image_Store_Allocation_Failed
                     then Terminal.Core.Kitty_ENOMEM
                     elsif R.Image_Transport_Failed
                     then Terminal.Core.Kitty_EBADF
                     elsif R.Last_Stored_Image_Order = 0
                       or else Find_Image_Object
                         (R, Event.Stream_ID, Header.Kitty_ID) = null
                     then Terminal.Core.Kitty_EINVAL
                     else Terminal.Core.Kitty_OK);
               elsif Header.Kitty_Action = 'T' then
                  Result.Code :=
                    (if (R.Last_Stored_Image_Order /= 0
                         and then Placement_Exists (0))
                       or else Frame_Image_Count (R) > Image_Count_Before
                     then Terminal.Core.Kitty_OK
                     elsif R.Image_Store_Allocation_Failed
                     then Terminal.Core.Kitty_ENOMEM
                     elsif R.Image_Transport_Failed
                     then Terminal.Core.Kitty_EBADF
                     else Terminal.Core.Kitty_EINVAL);
               end if;
            elsif Header.Kitty_Action = 'd' then
               Result.Image_ID := Resolved_ID;
               Result.Code := Terminal.Core.Kitty_OK;
            end if;
   
            if Header.Kitty_Action in 'T' | 'p'
              and then
                (Result.Code = Terminal.Core.Kitty_OK
                 or else
                   (Placement_Status in
                      Placement_Rejected | Placement_Parent_Missing
                        | Placement_Cycle | Placement_Too_Deep
                    and then Header.Kitty_Parent_ID /= 0))
            then
               if Result.Image_ID = 0
                 and then Header.Kitty_Image_Number /= 0
               then
                  declare
                     Stored : constant Image_Object_Access :=
                       Find_Image_Object_By_Number
                         (R, Event.Stream_ID, Header.Kitty_Image_Number);
                  begin
                     if Stored /= null then
                        Result.Image_ID := Stored.ID;
                     end if;
                  end;
               end if;
   
               if Geometry_Checked and then not Resolved_Geometry.Valid then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               elsif Header.Kitty_Virtual_Placement
                 and then Header.Kitty_Parent_ID /= 0
               then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               elsif Header.Kitty_Parent_ID /= 0 then
                  Result.Code :=
                    (case Validate_Relative_Placement
                       (R,
                        Event.Stream_ID,
                        Event.Alternate_Screen,
                        Event.Screen_Generation,
                        Result.Image_ID,
                        Header.Kitty_Placement_ID,
                        Header.Kitty_Parent_ID,
                        Header.Kitty_Parent_Placement_ID) is
                       when Relative_Valid => Terminal.Core.Kitty_OK,
                       when Relative_Parent_Missing =>
                         Terminal.Core.Kitty_ENOPARENT,
                       when Relative_Cycle => Terminal.Core.Kitty_ECYCLE,
                       when Relative_Too_Deep => Terminal.Core.Kitty_ETOODEEP);
               end if;
   
               if Result.Code = Terminal.Core.Kitty_OK
                 and then not Placement_Exists (Result.Image_ID)
               then
                  Result.Code :=
                    (if Placement_Status = Placement_Rejected
                     then Terminal.Core.Kitty_EINVAL
                     else Terminal.Core.Kitty_ENOMEM);
               elsif Result.Code = Terminal.Core.Kitty_OK
                 and then not Header.Kitty_No_Cursor_Move
                 and then not Header.Kitty_Virtual_Placement
                 and then Header.Kitty_Parent_ID = 0
               then
                  Result.Move_Cursor := True;
                  if Geometry_Checked and then Resolved_Geometry.Valid then
                     Result.Placement_Columns := Resolved_Geometry.Columns;
                     Result.Placement_Rows := Resolved_Geometry.Rows;
                  else
                     Result.Placement_Columns := Header.Placeholder_Cols;
                     Result.Placement_Rows := Header.Placeholder_Rows;
                  end if;
               end if;
            end if;
         end if;
         if Result.Code = Terminal.Core.Kitty_EINVAL
           and then Header.Kitty_Action in 't' | 'T' | 'f' | 'q'
           and then Header.Has_Data
           and then not R.Image_Transport_Failed
           and then not R.Image_Store_Allocation_Failed
         then
            R.Decode_Failure_Count := R.Decode_Failure_Count + 1;
         end if;
         Remember_Processed_Graphics_Event (R, Event, Result);
      elsif Replay_Guarded then
         --  Sixel and iTerm2 commands also install persistent image objects.
         --  A swapchain retry can render the same pending core event more
         --  than once before presentation commits it, so guard these
         --  side-effects exactly like stateful Kitty commands. iTerm2 can
         --  carry an internal cursor-commit result but emits no reply.
         Remember_Processed_Graphics_Event (R, Event, Result);
      end if;
   end Finalize_Response;

