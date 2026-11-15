with Terminal.App.Renderer.Animation_Frame_Decoding;
with Terminal.App.Renderer.Animation_Frame_Canvas;

separate (Terminal.App.Renderer.Animations)
procedure Apply_Frame
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Text   : String;
      Allow_Unknown_Compressed_PNG_Size : Boolean := False)
is
      Object : constant Image_Object_Access :=
        Objects.Find (R, Event.Stream_ID, Header.Kitty_ID);
      Decoded : Animation_Frame_Decoding.Result;
      Data : Terminal.App.Graphics.Graphics_Data_Preview
        renames Decoded.Data;
      Canvas_Length : Natural := 0;
      Target_Number : Natural := Header.Kitty_Frame_Number;
      Existing : Frames.Frame_Descriptor :=
        (Number => 1, Gap_MS => 0, Usage_Hint => 0, Length => 0);
      Canvas : Terminal.App.Owned_Image_Data.Owner;
      New_Frame : Boolean := False;
      Prepared_Operation : Theme_Operation_Access := null;
      Theme_Transaction : Themes.Append_Transaction
        (R.Graphics_State.Resources.Image_Objects'Access);

      procedure Fail (Code : Terminal.Core.Graphics_Completion_Code) is
      begin
         R.Graphics_State.Transaction.Last_Animation_Result := Code;
      end Fail;

      procedure Release_Local is
      begin
         Terminal.App.Graphics.Release (Data);
         Terminal.App.Owned_Image_Data.Release (Canvas);
         Themes.Release_Unowned
           (Prepared_Operation);
         Themes.Rollback (Theme_Transaction);
      end Release_Local;

      procedure Begin_Theme_Transaction is
      begin
         if Prepared_Operation /= null then
            if not Terminal.App.Image_Store.Allocation_Allowed
              (R.Graphics_State.Resources.Allocation_Control)
            then
               raise Storage_Error with "theme append allocation rejected";
            end if;
            Themes.Start (Theme_Transaction, Object, Prepared_Operation);
         end if;
      end Begin_Theme_Transaction;
   begin
      R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_EINVAL;
      Animation_Frame_Decoding.Decode
        (Header,
         Text,
         R.Graphics_State.Policy.Limits.Per_Image_Bytes,
         R.Graphics_State.Policy.Limits.Pixel_Dimension,
         Allow_Unknown_Compressed_PNG_Size,
         Decoded);
      if Decoded.Allocation_Failed then
         Fail (Terminal.Core.Graphics_ENOMEM);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Decoded.Quota_Failed then
         Fail (Terminal.Core.Graphics_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Object = null then
         Fail (Terminal.Core.Graphics_ENOENT);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Header.Kitty_ID = 0
        or else not Header.Has_Data
        or else Header.Kitty_Compression not in ASCII.NUL | 'z'
        or else Decoded.Copy_Failed
        or else not Data.Decode_Complete
        or else not Terminal.App.Graphics.Has_Bytes (Data)
        or else Data.Pixel_Width = 0
        or else Data.Pixel_Height = 0
        or else Data.Raw_Format not in 8 | 16 | 24 | 32
        or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
        or else Object.Pixel_Width * Object.Pixel_Height > Natural'Last / 4
      then
         Terminal.App.Graphics.Release (Data);
         return;
      end if;
      Canvas_Length := Object.Pixel_Width * Object.Pixel_Height * 4;
      if Canvas_Length > R.Graphics_State.Policy.Limits.Per_Image_Bytes
        or else Object.Pixel_Width > R.Graphics_State.Policy.Limits.Pixel_Dimension
        or else Object.Pixel_Height > R.Graphics_State.Policy.Limits.Pixel_Dimension
      then
         Fail (Terminal.Core.Graphics_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;
      if Target_Number = 0 then
         if Frames.Count (Object) >=
           Max_Kitty_Animation_Frames
           or else Objects.Stored_Animation_Frame_Count (R) >=
             R.Graphics_State.Policy.Limits.Animation_Frames
         then
            Fail (Terminal.Core.Graphics_ENOSPC);
            Terminal.App.Graphics.Release (Data);
            return;
         end if;
         Target_Number :=
           Frames.Count (Object) + 1;
         New_Frame := True;
      elsif not Frame_Exists (Object, Target_Number) then
         Fail (Terminal.Core.Graphics_ENOENT);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;
      if Target_Number > 1 and then not New_Frame then
         Existing := Frame_Info
           (Object, Positive (Target_Number));
      end if;

      if Header.Kitty_Source_X > Object.Pixel_Width
        or else Header.Kitty_Source_Y > Object.Pixel_Height
        or else Data.Pixel_Width > Object.Pixel_Width - Header.Kitty_Source_X
        or else Data.Pixel_Height > Object.Pixel_Height - Header.Kitty_Source_Y
      then
         Terminal.App.Graphics.Release (Data);
         return;
      end if;

      if New_Frame
        and then
          (Terminal.App.Image_Store.Owned_Bytes (Object.all) >
             R.Graphics_State.Policy.Limits.Per_Image_Bytes - Canvas_Length)
      then
         Fail (Terminal.Core.Graphics_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;

      Terminal.App.Owned_Image_Data.Allocate (Canvas, Canvas_Length);
      declare
         Prepared : Boolean;
         Failure  : Terminal.Core.Graphics_Completion_Code;
      begin
         Animation_Frame_Canvas.Prepare
           (Object,
            Positive (Target_Number),
            New_Frame,
            Header,
            Canvas,
            Prepared,
            Failure);
         if not Prepared then
            Fail (Failure);
            Release_Local;
            return;
         end if;
      end;

      if not Image_Theme_State.Prepare_Theme_Frame_Operation
        (R,
         Object,
         Header,
         Data,
         Positive (Target_Number),
         New_Frame,
         Prepared_Operation)
      then
         Fail (Terminal.Core.Graphics_ENOSPC);
         Release_Local;
         return;
      end if;

      --  Complete all decode/composition work before quota admission.  From
      --  this point onward the commit plan contains only bounded store
      --  mutations with their own rollback paths.
      Composite_Frame (R, Object, Header, Data, Canvas);

      declare
         Current_Total : constant Natural :=
           Terminal.App.Image_Store.Owned_Bytes (Object.all);
         Removed : constant Natural :=
           (if Target_Number = 1
            then Objects.Stored_Root_Length (Object)
              + Objects.Stored_Indexed_Length (Object)
            elsif New_Frame then 0
            else Existing.Length);
         Operation_Length : constant Natural :=
           (if Prepared_Operation = null then 0
            else Themes.Unowned_Length (Prepared_Operation));
         Added : Natural;
      begin
         if Operation_Length > Natural'Last - Canvas_Length then
            Fail (Terminal.Core.Graphics_ENOSPC);
            Release_Local;
            return;
         end if;
         Added := Canvas_Length + Operation_Length;
         if Added > R.Graphics_State.Policy.Limits.Per_Image_Bytes
           or else Current_Total - Removed >
             R.Graphics_State.Policy.Limits.Per_Image_Bytes - Added
           or else Added > R.Graphics_State.Policy.Limits.Image_Bytes
         then
            Fail (Terminal.Core.Graphics_ENOSPC);
            Release_Local;
            return;
         end if;
         --  Animation updates never evict unrelated objects.  Frame creation,
         --  theme-history attachment, and store synchronization remain
         --  fallible after this check; eviction here would make a rejected
         --  update externally destructive.  A caller can delete images and
         --  retry when the persistent quota is exhausted.
         if Objects.Stored_Bytes (R) - Removed >
           R.Graphics_State.Policy.Limits.Image_Bytes - Added
         then
            Fail (Terminal.Core.Graphics_ENOSPC);
            Release_Local;
            return;
         end if;
      end;

      if Target_Number = 1 then
         declare
            Old_Length : constant Natural :=
              Objects.Stored_Root_Length (Object);
            Old_Indexed_Length : constant Natural :=
              Objects.Stored_Indexed_Length (Object);
            Other_Bytes : constant Natural :=
              Terminal.App.Image_Store.Owned_Bytes (Object.all)
              - Old_Length - Old_Indexed_Length;
         begin
            if Other_Bytes >
              R.Graphics_State.Policy.Limits.Per_Image_Bytes - Canvas_Length
            then
               Fail (Terminal.Core.Graphics_ENOMEM);
               Release_Local;
               return;
            end if;
            if Canvas_Length > Old_Length + Old_Indexed_Length
              and then Objects.Stored_Bytes (R) >
                R.Graphics_State.Policy.Limits.Image_Bytes
                  - (Canvas_Length - Old_Length - Old_Indexed_Length)
            then
               Fail (Terminal.Core.Graphics_ENOMEM);
               Release_Local;
               return;
            end if;
            Begin_Theme_Transaction;
            Terminal.App.Image_Store.Replace_Root_RGBA
              (R.Graphics_State.Resources.Image_Objects,
               Object,
               Canvas,
               Set_Root_Gap => Header.Kitty_Frame_Gap /= 0,
               Root_Gap_MS  => Header.Kitty_Frame_Gap);
         end;
      elsif New_Frame then
         declare
            Frame_To_Adopt : Image_Frame_Access := null;
            Frame_Usage : constant Natural :=
              (if Header.Kitty_Usage_Hint = 1
                 or else
                   (Header.Kitty_Base_Frame > 0
                    and then
                      (if Header.Kitty_Base_Frame = 1
                       then Object.Usage_Hint = 1
                       else Frame_Info
                         (Object, Positive (Header.Kitty_Base_Frame)).
                           Usage_Hint = 1))
               then 1
               else Header.Kitty_Usage_Hint);
         begin
            Begin_Theme_Transaction;
            Frames.Create
              (Positive (Target_Number),
               (if Header.Kitty_Frame_Gap = 0
                then 40
                else Header.Kitty_Frame_Gap),
               Frame_Usage,
               Canvas,
               Frame_To_Adopt);
            begin
               Frames.Append
                 (R.Graphics_State.Resources.Image_Objects,
                  Object,
                  Frame_To_Adopt);
            exception
               when others =>
                  Frames.Release_Unowned (Frame_To_Adopt);
                  raise;
            end;
         end;
      else
         Begin_Theme_Transaction;
         Frames.Replace_Data
           (R.Graphics_State.Resources.Image_Objects,
            Object,
            Positive (Target_Number),
            Canvas,
            Set_Gap    => Header.Kitty_Frame_Gap /= 0,
            Gap_MS     => Header.Kitty_Frame_Gap,
            Set_Usage  => Header.Kitty_Usage_Hint = 1,
            Usage_Hint => 1);
      end if;
      Themes.Commit (Theme_Transaction);
      Objects.Touch (R, Object);
      R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_OK;
      Release_Local;
   exception
      when Storage_Error =>
         Release_Local;
         R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_ENOMEM;
      when others =>
         Release_Local;
         raise;
end Apply_Frame;
