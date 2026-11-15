separate (Terminal.App.Renderer.Animations)
procedure Apply_Composition
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header)
is
      Object : constant Image_Object_Access :=
        Objects.Find (R, Event.Stream_ID, Header.Kitty_ID);
      Source : Terminal.App.Owned_Image_Data.Owner;
      Target : Terminal.App.Owned_Image_Data.Owner;
      Source_Valid : Boolean := False;
      Target_Valid : Boolean := False;
      Width  : Natural := Header.Kitty_Source_Width;
      Height : Natural := Header.Kitty_Source_Height;
      Source_Frame : Positive := 1;
      Target_Frame : Positive := 1;
      Prepared_Operation : Theme_Operation_Access := null;
      Theme_Transaction : Themes.Append_Transaction
        (R.Graphics_State.Resources.Image_Objects'Access);

      procedure Release_Local is
      begin
         Terminal.App.Owned_Image_Data.Release (Source);
         Terminal.App.Owned_Image_Data.Release (Target);
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
      if Object = null then
         R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_ENOENT;
         return;
      elsif Header.Kitty_Base_Frame = 0
        or else Header.Kitty_Frame_Number = 0
        or else not Frame_Exists
          (Object, Header.Kitty_Base_Frame)
        or else not Frame_Exists
          (Object, Header.Kitty_Frame_Number)
      then
         R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_ENOENT;
         return;
      elsif Object.Pixel_Width = 0
        or else Object.Pixel_Height = 0
        or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
        or else Object.Pixel_Width * Object.Pixel_Height > Natural'Last / 4
        or else Header.Kitty_Composition_Mode > 1
      then
         return;
      end if;
      Source_Frame := Positive (Header.Kitty_Base_Frame);
      Target_Frame := Positive (Header.Kitty_Frame_Number);
      if Width = 0 then
         Width := Object.Pixel_Width;
      end if;
      if Height = 0 then
         Height := Object.Pixel_Height;
      end if;
      if Width = 0 or else Height = 0
        or else Header.Kitty_Cell_X > Object.Pixel_Width
        or else Header.Kitty_Cell_Y > Object.Pixel_Height
        or else Header.Kitty_Source_X > Object.Pixel_Width
        or else Header.Kitty_Source_Y > Object.Pixel_Height
        or else Width > Object.Pixel_Width - Header.Kitty_Cell_X
        or else Height > Object.Pixel_Height - Header.Kitty_Cell_Y
        or else Width > Object.Pixel_Width - Header.Kitty_Source_X
        or else Height > Object.Pixel_Height - Header.Kitty_Source_Y
      then
         return;
      end if;
      if Source_Frame = Target_Frame
        and then Header.Kitty_Cell_X < Header.Kitty_Source_X + Width
        and then Header.Kitty_Source_X < Header.Kitty_Cell_X + Width
        and then Header.Kitty_Cell_Y < Header.Kitty_Source_Y + Height
        and then Header.Kitty_Source_Y < Header.Kitty_Cell_Y + Height
      then
         return;
      end if;

      if not Terminal.App.Image_Store.Allocation_Allowed
        (R.Graphics_State.Resources.Allocation_Control)
      then
         raise Storage_Error with "composition working allocation rejected";
      end if;
      Terminal.App.Owned_Image_Data.Allocate
        (Source, Object.Pixel_Width * Object.Pixel_Height * 4);
      Terminal.App.Owned_Image_Data.Allocate
        (Target, Object.Pixel_Width * Object.Pixel_Height * 4);
      declare
         procedure Copy_Source
           (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
         begin
            Copy_Frame_To_RGBA
              (Object, Source_Frame, Bytes, Source_Valid);
         end Copy_Source;
         procedure Copy_Target
           (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
         begin
            Copy_Frame_To_RGBA
              (Object, Target_Frame, Bytes, Target_Valid);
         end Copy_Target;
      begin
         Terminal.App.Owned_Image_Data.Modify (Source, Copy_Source'Access);
         Terminal.App.Owned_Image_Data.Modify (Target, Copy_Target'Access);
      end;
      if not Source_Valid or else not Target_Valid then
         Release_Local;
         return;
      end if;
      if not Image_Theme_State.Prepare_Theme_Composition_Operation
        (R,
         Object,
         Header,
         Source_Frame,
         Target_Frame,
         Width,
         Height,
         Prepared_Operation)
      then
         Release_Local;
         R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_ENOSPC;
         return;
      end if;

      declare
         procedure Blend_Target
           (Target_Bytes : in out Terminal.Common.Bytes.Byte_Array) is
            procedure Blend_Source
              (Source_Bytes : Terminal.Common.Bytes.Byte_Array) is
            begin
               for Y in 0 .. Height - 1 loop
                  for X in 0 .. Width - 1 loop
                     declare
                        SI : constant Positive := Positive
                          (((Header.Kitty_Source_Y + Y) * Object.Pixel_Width
                            + Header.Kitty_Source_X + X) * 4 + 1);
                        DI : constant Positive := Positive
                          (((Header.Kitty_Cell_Y + Y) * Object.Pixel_Width
                            + Header.Kitty_Cell_X + X) * 4 + 1);
                        SA : constant Natural :=
                          Natural (Source_Bytes (SI + 3));
                     begin
                        if Header.Kitty_Composition_Mode = 1 or else SA = 255
                        then
                           Target_Bytes (DI .. DI + 3) :=
                             Source_Bytes (SI .. SI + 3);
                        elsif SA > 0 then
                           declare
                              DA : constant Natural :=
                                Natural (Target_Bytes (DI + 3));
                              OA : constant Natural :=
                                SA + (DA * (255 - SA) + 127) / 255;
                              Denom : constant Natural :=
                                Natural'Max (1, OA * 255);
                           begin
                              for C in 0 .. 2 loop
                                 Target_Bytes (DI + C) :=
                                   Terminal.Common.Bytes.Byte
                                     ((Natural (Source_Bytes (SI + C))
                                       * SA * 255
                                       + Natural (Target_Bytes (DI + C))
                                         * DA * (255 - SA)
                                       + Denom / 2) / Denom);
                              end loop;
                              Target_Bytes (DI + 3) :=
                                Terminal.Common.Bytes.Byte (OA);
                           end;
                        end if;
                     end;
                  end loop;
               end loop;
            end Blend_Source;
         begin
            Terminal.App.Owned_Image_Data.Read
              (Source, Blend_Source'Access);
         end Blend_Target;
      begin
         Terminal.App.Owned_Image_Data.Modify (Target, Blend_Target'Access);
      end;

      declare
         Current_Total : constant Natural :=
           Terminal.App.Image_Store.Owned_Bytes (Object.all);
         Removed : constant Natural :=
           (if Target_Frame = 1
            then Objects.Stored_Root_Length (Object)
              + Objects.Stored_Indexed_Length (Object)
            else Frame_Info (Object, Target_Frame).Length);
         Target_Length : constant Natural :=
           Terminal.App.Owned_Image_Data.Length (Target);
         Operation_Length : constant Natural :=
           Themes.Unowned_Length (Prepared_Operation);
         Added : Natural;
      begin
         if Operation_Length > Natural'Last - Target_Length then
            Release_Local;
            R.Graphics_State.Transaction.Last_Animation_Result :=
              Terminal.Core.Graphics_ENOSPC;
            return;
         end if;
         Added := Target_Length + Operation_Length;
         if Added > R.Graphics_State.Policy.Limits.Per_Image_Bytes
           or else Current_Total - Removed >
             R.Graphics_State.Policy.Limits.Per_Image_Bytes - Added
           or else Added > R.Graphics_State.Policy.Limits.Image_Bytes
         then
            Release_Local;
            R.Graphics_State.Transaction.Last_Animation_Result :=
              Terminal.Core.Graphics_ENOSPC;
            return;
         end if;
         if Objects.Stored_Bytes (R) - Removed >
           R.Graphics_State.Policy.Limits.Image_Bytes - Added
         then
            Release_Local;
            R.Graphics_State.Transaction.Last_Animation_Result :=
              Terminal.Core.Graphics_ENOSPC;
            return;
         end if;
      end;

      if Target_Frame = 1 then
         declare
            Old_Length : constant Natural :=
              Objects.Stored_Root_Length (Object);
            Old_Indexed_Length : constant Natural :=
              Objects.Stored_Indexed_Length (Object);
            New_Length : constant Natural :=
              Terminal.App.Owned_Image_Data.Length (Target);
         begin
            if New_Length > Old_Length + Old_Indexed_Length
              and then Objects.Stored_Bytes (R) >
                R.Graphics_State.Policy.Limits.Image_Bytes - Natural'Min
                  (New_Length - Old_Length - Old_Indexed_Length,
                   R.Graphics_State.Policy.Limits.Image_Bytes)
            then
               Release_Local;
               R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_ENOSPC;
               return;
            end if;
            Begin_Theme_Transaction;
            Terminal.App.Image_Store.Replace_Root_RGBA
              (R.Graphics_State.Resources.Image_Objects,
               Object,
               Target,
               Set_Usage =>
                 Source_Frame /= 1
                 and then Frame_Info
                   (Object, Source_Frame).Usage_Hint = 1,
               Usage_Hint => 1);
         end;
      else
         declare
            Frame : constant Frames.Frame_Descriptor :=
              Frame_Info (Object, Target_Frame);
         begin
            Begin_Theme_Transaction;
            Frames.Replace_Data
              (R.Graphics_State.Resources.Image_Objects,
               Object,
               Target_Frame,
               Target,
               Set_Usage =>
                 Frame.Usage_Hint = 1
                 or else
                   (if Source_Frame = 1
                    then Object.Usage_Hint = 1
                    else Frame_Info
                      (Object, Source_Frame).Usage_Hint = 1),
               Usage_Hint => 1);
         end;
      end if;
      Themes.Commit (Theme_Transaction);
      Objects.Touch (R, Object);
      Release_Local;
      R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_OK;
   exception
      when Storage_Error =>
         Release_Local;
         R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_ENOMEM;
      when others =>
         Release_Local;
         raise;
end Apply_Composition;
