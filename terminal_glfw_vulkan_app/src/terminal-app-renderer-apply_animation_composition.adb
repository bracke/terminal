separate (Terminal.App.Renderer)
procedure Apply_Animation_Composition
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header)
is
      Object : constant Image_Object_Access :=
        Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
      Source : RM.Image_Data_Access := null;
      Target : RM.Image_Data_Access := null;
      Source_Valid : Boolean := False;
      Target_Valid : Boolean := False;
      Width  : Natural := Header.Kitty_Source_Width;
      Height : Natural := Header.Kitty_Source_Height;
      Source_Frame : Positive := 1;
      Target_Frame : Positive := 1;
      Prepared_Operation : Theme_Operation_Access := null;
      Theme_Transaction : Terminal.App.Image_Store.Theme_Append_Transaction
        (R.Image_Objects'Access);

      procedure Release_Local is
      begin
         Free_Image_Data (Source);
         Free_Image_Data (Target);
         Themes.Release_Unowned
           (Prepared_Operation);
         Terminal.App.Image_Store.Rollback_Theme_Append
           (Theme_Transaction);
      end Release_Local;

      procedure Begin_Theme_Transaction is
      begin
         if Prepared_Operation /= null then
            if not Terminal.App.Image_Store.Allocation_Allowed
              (R.Image_Allocation_Control)
            then
               raise Storage_Error with "theme append allocation rejected";
            end if;
            Terminal.App.Image_Store.Begin_Theme_Append
              (Theme_Transaction, Object, Prepared_Operation);
         end if;
      end Begin_Theme_Transaction;
   begin
      R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
      if Object = null then
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOENT;
         return;
      elsif Header.Kitty_Base_Frame = 0
        or else Header.Kitty_Frame_Number = 0
        or else not Animation_Frame_Exists
          (Object, Header.Kitty_Base_Frame)
        or else not Animation_Frame_Exists
          (Object, Header.Kitty_Frame_Number)
      then
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOENT;
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
        (R.Image_Allocation_Control)
      then
         raise Storage_Error with "composition working allocation rejected";
      end if;
      Source := new Terminal.Common.Bytes.Byte_Array
        (1 .. Object.Pixel_Width * Object.Pixel_Height * 4);
      Target := new Terminal.Common.Bytes.Byte_Array
        (1 .. Object.Pixel_Width * Object.Pixel_Height * 4);
      Copy_Frame_To_RGBA (Object, Source_Frame, Source.all, Source_Valid);
      Copy_Frame_To_RGBA (Object, Target_Frame, Target.all, Target_Valid);
      if not Source_Valid or else not Target_Valid then
         Release_Local;
         return;
      end if;
      if not Prepare_Theme_Composition_Operation
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
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOSPC;
         return;
      end if;

      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            declare
               SI : constant Positive := Positive
                 (((Header.Kitty_Cell_Y + Y) * Object.Pixel_Width
                   + Header.Kitty_Cell_X + X) * 4 + 1);
               DI : constant Positive := Positive
                 (((Header.Kitty_Source_Y + Y) * Object.Pixel_Width
                   + Header.Kitty_Source_X + X) * 4 + 1);
               SA : constant Natural := Natural (Source (SI + 3));
            begin
               if Header.Kitty_Composition_Mode = 1 or else SA = 255 then
                  Target (DI .. DI + 3) := Source (SI .. SI + 3);
               elsif SA > 0 then
                  declare
                     DA : constant Natural := Natural (Target (DI + 3));
                     OA : constant Natural :=
                       SA + (DA * (255 - SA) + 127) / 255;
                     Denom : constant Natural := Natural'Max (1, OA * 255);
                  begin
                     for C in 0 .. 2 loop
                        Target (DI + C) := Terminal.Common.Bytes.Byte
                          ((Natural (Source (SI + C)) * SA * 255
                            + Natural (Target (DI + C)) * DA * (255 - SA)
                            + Denom / 2) / Denom);
                     end loop;
                     Target (DI + 3) := Terminal.Common.Bytes.Byte (OA);
                  end;
               end if;
            end;
         end loop;
      end loop;

      if Target_Frame = 1 then
         declare
            Old_Length : constant Natural := Allocation_Length
              (Terminal.App.Image_Store.Root_Data (Object));
            Old_Indexed_Length : constant Natural :=
              Allocation_Length
                (Terminal.App.Image_Store.Indexed_Data (Object));
            New_Length : constant Natural := Target'Length;
         begin
            if New_Length > Old_Length + Old_Indexed_Length
              and then Stored_Image_Bytes (R) >
                R.Graphics_Limits.Image_Bytes - Natural'Min
                  (New_Length - Old_Length - Old_Indexed_Length,
                   R.Graphics_Limits.Image_Bytes)
            then
               Release_Local;
               R.Last_Animation_Result := Terminal.Core.Kitty_ENOSPC;
               return;
            end if;
            Begin_Theme_Transaction;
            Terminal.App.Image_Store.Replace_Root_RGBA
              (R.Image_Objects, Object, Target);
            if Source_Frame = 1 then
               null;
            elsif Find_Image_Frame (Object, Source_Frame).Usage_Hint = 1 then
               Terminal.App.Image_Store.Set_Usage_Hint (Object, 1);
            end if;
         end;
      else
         declare
            Frame : constant Image_Frame_Access :=
              Find_Image_Frame (Object, Target_Frame);
         begin
            Begin_Theme_Transaction;
            Terminal.App.Image_Store.Replace_Frame_Data
              (R.Image_Objects, Object, Target_Frame, Target);
            if Frame.Usage_Hint = 1
              or else
                (if Source_Frame = 1
                 then Object.Usage_Hint = 1
                 else Find_Image_Frame (Object, Source_Frame).Usage_Hint = 1)
            then
               Terminal.App.Image_Store.Set_Usage_Hint (Frame, 1);
            end if;
         end;
      end if;
      Terminal.App.Image_Store.Commit (Theme_Transaction);
      Touch_Image_Object (R, Object);
      Release_Local;
      R.Last_Animation_Result := Terminal.Core.Kitty_OK;
   exception
      when Storage_Error =>
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOMEM;
      when Constraint_Error =>
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
      when others =>
         Release_Local;
         raise;
end Apply_Animation_Composition;
