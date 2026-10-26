separate (Terminal.App.Renderer)
procedure Apply_Animation_Frame
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Text   : String;
      Allow_Unknown_Compressed_PNG_Size : Boolean := False)
is
      Object : constant Image_Object_Access :=
        Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
      Data : Terminal.App.Graphics.Graphics_Data_Preview :=
        (Header_Recognized => Header.Recognized,
         Has_Data          => Header.Has_Data,
         Raw_Format        => Header.Raw_Format,
         Pixel_Width       => Header.Pixel_Width,
         Pixel_Height      => Header.Pixel_Height,
         others            => <>);
      Canvas_Length : Natural := 0;
      Target_Number : Natural := Header.Kitty_Frame_Number;
      Existing : Image_Frame_Access := null;
      Canvas : RM.Image_Data_Access := null;
      Canvas_Owned : Boolean := False;
      Base_Valid : Boolean := False;
      New_Frame : Boolean := False;
      Compressed_Bytes : RM.Image_Data_Access := null;
      Compressed_Bytes_Owned : Boolean := False;
      Row_Copy_Failed : Boolean := False;
      Row_Quota_Failed : Boolean := False;
      Row_Allocation_Failed : Boolean := False;
      Prepared_Operation : Theme_Operation_Access := null;
      Theme_Transaction : Themes.Append_Transaction
        (R.Image_Objects'Access);

      function Data_Start return Natural is
      begin
         for I in Text'Range loop
            if Text (I) = ';' then
               return (if I < Text'Last then I + 1 else 0);
            end if;
         end loop;
         return 0;
      end Data_Start;

      function One_Chunk (Index : Positive) return String is
         First : constant Natural := Data_Start;
      begin
         if Index /= 1 or else First = 0 then
            return "";
         end if;
         return Text (First .. Text'Last);
      end One_Chunk;

      procedure Capture_Compressed_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         Required : Natural := 0;
         Offset : Natural := 0;
      begin
         if Data.Pixel_Height = 0
           or else Row'Length = 0
           or else Data.Pixel_Height > Natural'Last / Row'Length
         then
            Continue := False;
            Row_Copy_Failed := True;
            return;
         end if;
         Required := Data.Pixel_Height * Row'Length;
         if Required > R.Graphics_Limits.Per_Image_Bytes
           or else Data.Pixel_Width > R.Graphics_Limits.Pixel_Dimension
           or else Data.Pixel_Height > R.Graphics_Limits.Pixel_Dimension
           or else Y >= Data.Pixel_Height
         then
            Continue := False;
            Row_Copy_Failed := True;
            Row_Quota_Failed := True;
            return;
         end if;
         if Compressed_Bytes = null then
            Compressed_Bytes :=
              new Terminal.Common.Bytes.Byte_Array (1 .. Required);
            Compressed_Bytes.all := (others => 0);
            Compressed_Bytes_Owned := True;
         elsif Compressed_Bytes'Length /= Required then
            Continue := False;
            Row_Copy_Failed := True;
            return;
         end if;
         Offset := Y * Row'Length + 1;
         Compressed_Bytes (Offset .. Offset + Row'Length - 1) := Row;
         Continue := True;
      exception
         when Storage_Error =>
            Continue := False;
            Row_Copy_Failed := True;
            Row_Allocation_Failed := True;
      end Capture_Compressed_Row;

      procedure Fail (Code : Terminal.Core.Kitty_Graphics_Result_Code) is
      begin
         R.Last_Animation_Result := Code;
      end Fail;

      procedure Release_Local is
      begin
         Terminal.App.Graphics.Release (Data);
         if Canvas /= null and then Canvas_Owned then
            Free_Image_Data (Canvas);
         end if;
         Canvas := null;
         Themes.Release_Unowned
           (Prepared_Operation);
         Themes.Rollback (Theme_Transaction);
      end Release_Local;

      procedure Begin_Theme_Transaction is
      begin
         if Prepared_Operation /= null then
            if not Terminal.App.Image_Store.Allocation_Allowed
              (R.Image_Allocation_Control)
            then
               raise Storage_Error with "theme append allocation rejected";
            end if;
            Themes.Start (Theme_Transaction, Object, Prepared_Operation);
         end if;
      end Begin_Theme_Transaction;
   begin
      R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
      if Header.Kitty_Format in 8 | 16 | 24 | 32 then
         if Header.Kitty_Compression = 'z' then
            Terminal.App.Graphics.Decode_Base64_Zlib_Raw_Chunk_Rows
              (1,
               One_Chunk'Access,
               Header.Kitty_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Capture_Compressed_Row'Access,
               Data);
         else
            Terminal.App.Graphics.Decode_Base64_Raw_Chunk_Rows
              (1,
               One_Chunk'Access,
               Header.Kitty_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Capture_Compressed_Row'Access,
               Data);
         end if;
      elsif Header.Kitty_Format = 100 then
         if Header.Kitty_Compression = 'z'
           and then
             (Header.Kitty_Data_Size > 0
              or else Allow_Unknown_Compressed_PNG_Size)
         then
            declare
               Encoded_Length : Natural := 0;
            begin
               Terminal.App.Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
                 (1,
                  One_Chunk'Access,
                  Header.Kitty_Data_Size,
                  Encoded_Length,
                  Capture_Compressed_Row'Access,
                  Data);
            end;
         elsif Header.Kitty_Compression = ASCII.NUL then
            declare
               Encoded_Length : Natural := 0;
               PNG_Length : Natural := 0;
            begin
               Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
                 (1,
                  One_Chunk'Access,
                  Encoded_Length,
                  PNG_Length,
                  Capture_Compressed_Row'Access,
                  Data);
            end;
         end if;
      end if;
      if Data.Bytes /= null then
         Terminal.App.Graphics.Release (Data);
      end if;
      Data.Bytes := Compressed_Bytes;
      Compressed_Bytes := null;
      Compressed_Bytes_Owned := False;
      if Row_Allocation_Failed then
         Fail (Terminal.Core.Kitty_ENOMEM);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Row_Quota_Failed then
         Fail (Terminal.Core.Kitty_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Object = null then
         Fail (Terminal.Core.Kitty_ENOENT);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Header.Kitty_ID = 0
        or else not Header.Has_Data
        or else Header.Kitty_Compression not in ASCII.NUL | 'z'
        or else Row_Copy_Failed
        or else not Data.Decode_Complete
        or else Data.Bytes = null
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
      if Canvas_Length > R.Graphics_Limits.Per_Image_Bytes
        or else Object.Pixel_Width > R.Graphics_Limits.Pixel_Dimension
        or else Object.Pixel_Height > R.Graphics_Limits.Pixel_Dimension
      then
         Fail (Terminal.Core.Kitty_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;
      if Target_Number = 0 then
         if Terminal.App.Image_Store.Frame_Count_Of (Object) >=
           Max_Kitty_Animation_Frames
           or else Stored_Animation_Frame_Count (R) >=
             R.Graphics_Limits.Animation_Frames
         then
            Fail (Terminal.Core.Kitty_ENOSPC);
            Terminal.App.Graphics.Release (Data);
            return;
         end if;
         Target_Number :=
           Terminal.App.Image_Store.Frame_Count_Of (Object) + 1;
         New_Frame := True;
      elsif not Animation_Frame_Exists (Object, Target_Number) then
         Fail (Terminal.Core.Kitty_ENOENT);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;
      if Target_Number > 1 then
         Existing := Find_Image_Frame (Object, Positive (Target_Number));
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
             R.Graphics_Limits.Per_Image_Bytes - Canvas_Length)
      then
         Fail (Terminal.Core.Kitty_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;

      if New_Frame
        and then Stored_Image_Bytes (R) >
          R.Graphics_Limits.Image_Bytes - Natural'Min
            (Canvas_Length, R.Graphics_Limits.Image_Bytes)
      then
         while Stored_Image_Bytes (R) >
           R.Graphics_Limits.Image_Bytes - Natural'Min
             (Canvas_Length, R.Graphics_Limits.Image_Bytes)
         loop
            if Canvas_Length > R.Graphics_Limits.Image_Bytes
              or else not Evict_One_Unplaced_Image
                (R, Event.Stream_ID, Header.Kitty_ID)
            then
               Fail (Terminal.Core.Kitty_ENOSPC);
               Terminal.App.Graphics.Release (Data);
               return;
            end if;
         end loop;
      end if;

      Canvas := new Terminal.Common.Bytes.Byte_Array (1 .. Canvas_Length);
      Canvas_Owned := True;
      if New_Frame then
         if Header.Kitty_Base_Frame > 0 then
            if not Animation_Frame_Exists (Object, Header.Kitty_Base_Frame) then
               Fail (Terminal.Core.Kitty_ENOENT);
               Release_Local;
               return;
            end if;
            Copy_Frame_To_RGBA
              (Object, Positive (Header.Kitty_Base_Frame), Canvas.all, Base_Valid);
            if not Base_Valid then
               Release_Local;
               return;
            end if;
         else
            declare
               Color : constant Terminal.Core.Graphics_ID :=
                 Header.Kitty_Background_Color;
               Red   : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte (Interfaces.Shift_Right
                   (Interfaces.Unsigned_32 (Color), 24));
               Green : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte (Interfaces.Shift_Right
                   (Interfaces.Unsigned_32 (Color), 16) and 16#FF#);
               Blue  : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte (Interfaces.Shift_Right
                   (Interfaces.Unsigned_32 (Color), 8) and 16#FF#);
               Alpha : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte
                   (Interfaces.Unsigned_32 (Color) and 16#FF#);
            begin
               for Pixel in 0 .. Object.Pixel_Width * Object.Pixel_Height - 1 loop
                  Canvas (Pixel * 4 + 1) := Red;
                  Canvas (Pixel * 4 + 2) := Green;
                  Canvas (Pixel * 4 + 3) := Blue;
                  Canvas (Pixel * 4 + 4) := Alpha;
               end loop;
            end;
         end if;
      else
         Copy_Frame_To_RGBA
           (Object, Positive (Target_Number), Canvas.all, Base_Valid);
         if not Base_Valid then
            Release_Local;
            return;
         end if;
      end if;

      if not Prepare_Theme_Frame_Operation
        (R,
         Object,
         Header,
         Data,
         Positive (Target_Number),
         New_Frame,
         Prepared_Operation)
      then
         Fail (Terminal.Core.Kitty_ENOSPC);
         Release_Local;
         return;
      end if;

      declare
         Current_Total : constant Natural :=
           Terminal.App.Image_Store.Owned_Bytes (Object.all);
         Removed : constant Natural :=
           (if Target_Number = 1
            then Allocation_Length
              (Terminal.App.Image_Store.Root_Data (Object))
              + Allocation_Length
                (Terminal.App.Image_Store.Indexed_Data (Object))
            elsif New_Frame then 0
            else Allocation_Length (Existing.Bytes));
         Operation_Length : constant Natural :=
           (if Prepared_Operation = null then 0
            else Prepared_Operation.Length);
         Added : Natural;
      begin
         if Operation_Length > Natural'Last - Canvas_Length then
            Fail (Terminal.Core.Kitty_ENOSPC);
            Release_Local;
            return;
         end if;
         Added := Canvas_Length + Operation_Length;
         if Added > R.Graphics_Limits.Per_Image_Bytes
           or else Current_Total - Removed >
             R.Graphics_Limits.Per_Image_Bytes - Added
           or else Added > R.Graphics_Limits.Image_Bytes
         then
            Fail (Terminal.Core.Kitty_ENOSPC);
            Release_Local;
            return;
         end if;
         while Stored_Image_Bytes (R) - Removed >
           R.Graphics_Limits.Image_Bytes - Added
         loop
            if not Evict_One_Unplaced_Image
              (R, Event.Stream_ID, Header.Kitty_ID)
            then
               Fail (Terminal.Core.Kitty_ENOSPC);
               Release_Local;
               return;
            end if;
         end loop;
      end;

      for Y in 0 .. Data.Pixel_Height - 1 loop
         for X in 0 .. Data.Pixel_Width - 1 loop
            declare
               Source_Index : constant Positive :=
                 Positive
                   (Y * Data.Decoded_Row_Stride_Bytes
                    + X
                      * (if Data.Raw_Format = 8 then 1
                         elsif Data.Raw_Format = 16 then 2
                         else Data.Raw_Format / 8)
                    + 1);
               Target_Index : constant Positive :=
                 Positive
                   (((Header.Kitty_Source_Y + Y) * Object.Pixel_Width
                     + Header.Kitty_Source_X + X) * 4 + 1);
               Palette_Color : constant RM.Pixel_Color :=
                 (if Data.Raw_Format in 8 | 16
                  then Kitty_Indexed_Color
                    (R, Natural (Data.Bytes (Source_Index)))
                  else (0.0, 0.0, 0.0, 1.0));
               SR : constant Natural :=
                 (if Data.Raw_Format in 8 | 16
                  then Natural (Color_Byte (Palette_Color.R))
                  else Natural (Data.Bytes (Source_Index)));
               SG : constant Natural :=
                 (if Data.Raw_Format in 8 | 16
                  then Natural (Color_Byte (Palette_Color.G))
                  else Natural (Data.Bytes (Source_Index + 1)));
               SB : constant Natural :=
                 (if Data.Raw_Format in 8 | 16
                  then Natural (Color_Byte (Palette_Color.B))
                  else Natural (Data.Bytes (Source_Index + 2)));
               SA : constant Natural :=
                 (if Data.Raw_Format = 16
                  then Natural (Data.Bytes (Source_Index + 1))
                  elsif Data.Raw_Format = 32
                  then Natural (Data.Bytes (Source_Index + 3))
                  else 255);
            begin
               if Header.Kitty_Composition_Mode = 1 or else SA = 255 then
                  Canvas (Target_Index) := Terminal.Common.Bytes.Byte (SR);
                  Canvas (Target_Index + 1) := Terminal.Common.Bytes.Byte (SG);
                  Canvas (Target_Index + 2) := Terminal.Common.Bytes.Byte (SB);
                  Canvas (Target_Index + 3) := Terminal.Common.Bytes.Byte (SA);
               elsif SA > 0 then
                  declare
                     DR : constant Natural := Natural (Canvas (Target_Index));
                     DG : constant Natural := Natural (Canvas (Target_Index + 1));
                     DB : constant Natural := Natural (Canvas (Target_Index + 2));
                     DA : constant Natural := Natural (Canvas (Target_Index + 3));
                     OA : constant Natural := SA + (DA * (255 - SA) + 127) / 255;
                     Denom : constant Natural := Natural'Max (1, OA * 255);
                  begin
                     Canvas (Target_Index) := Terminal.Common.Bytes.Byte
                       ((SR * SA * 255 + DR * DA * (255 - SA) + Denom / 2)
                        / Denom);
                     Canvas (Target_Index + 1) := Terminal.Common.Bytes.Byte
                       ((SG * SA * 255 + DG * DA * (255 - SA) + Denom / 2)
                        / Denom);
                     Canvas (Target_Index + 2) := Terminal.Common.Bytes.Byte
                       ((SB * SA * 255 + DB * DA * (255 - SA) + Denom / 2)
                        / Denom);
                     Canvas (Target_Index + 3) := Terminal.Common.Bytes.Byte (OA);
                  end;
               end if;
            end;
         end loop;
      end loop;

      if Target_Number = 1 then
         declare
            Old_Length : constant Natural := Allocation_Length
              (Terminal.App.Image_Store.Root_Data (Object));
            Old_Indexed_Length : constant Natural :=
              Allocation_Length
                (Terminal.App.Image_Store.Indexed_Data (Object));
            Other_Bytes : constant Natural :=
              Terminal.App.Image_Store.Owned_Bytes (Object.all)
              - Old_Length - Old_Indexed_Length;
         begin
            if Other_Bytes >
              R.Graphics_Limits.Per_Image_Bytes - Canvas_Length
            then
               Fail (Terminal.Core.Kitty_ENOMEM);
               Release_Local;
               return;
            end if;
            if Canvas_Length > Old_Length + Old_Indexed_Length
              and then Stored_Image_Bytes (R) >
                R.Graphics_Limits.Image_Bytes
                  - (Canvas_Length - Old_Length - Old_Indexed_Length)
            then
               Fail (Terminal.Core.Kitty_ENOMEM);
               Release_Local;
               return;
            end if;
            Begin_Theme_Transaction;
            Terminal.App.Image_Store.Replace_Root_RGBA
              (R.Image_Objects, Object, Canvas);
            Canvas_Owned := False;
            if Header.Kitty_Frame_Gap /= 0 then
               Terminal.App.Image_Store.Set_Root_Gap
                 (Object, Header.Kitty_Frame_Gap);
            end if;
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
                       else Find_Image_Frame
                         (Object, Positive (Header.Kitty_Base_Frame)).
                           Usage_Hint = 1))
               then 1
               else Header.Kitty_Usage_Hint);
         begin
            Begin_Theme_Transaction;
            Terminal.App.Image_Store.Create_Frame
              (Positive (Target_Number),
               (if Header.Kitty_Frame_Gap = 0
                then 40
                else Header.Kitty_Frame_Gap),
               Frame_Usage,
               Canvas,
               Frame_To_Adopt);
            Canvas_Owned := False;
            Terminal.App.Image_Store.Append_Frame
              (R.Image_Objects, Object, Frame_To_Adopt);
            Canvas_Owned := False;
         end;
      else
         Begin_Theme_Transaction;
         Terminal.App.Image_Store.Replace_Frame_Data
           (R.Image_Objects, Object, Positive (Target_Number), Canvas);
         Canvas_Owned := False;
         if Header.Kitty_Frame_Gap /= 0 then
            if not Set_Animation_Frame_Gap
              (Object, Positive (Target_Number), Header.Kitty_Frame_Gap)
            then
               raise Constraint_Error;
            end if;
         end if;
         if Header.Kitty_Usage_Hint = 1 then
            Terminal.App.Image_Store.Set_Usage_Hint (Existing, 1);
         end if;
      end if;
      Themes.Commit (Theme_Transaction);
      Touch_Image_Object (R, Object);
      R.Last_Animation_Result := Terminal.Core.Kitty_OK;
      Release_Local;
   exception
      when Storage_Error =>
         if Compressed_Bytes /= null and then Compressed_Bytes_Owned then
            Free_Image_Data (Compressed_Bytes);
         end if;
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOMEM;
      when Constraint_Error =>
         if Compressed_Bytes /= null and then Compressed_Bytes_Owned then
            Free_Image_Data (Compressed_Bytes);
         end if;
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
      when others =>
         if Compressed_Bytes /= null and then Compressed_Bytes_Owned then
            Free_Image_Data (Compressed_Bytes);
         end if;
         Release_Local;
         raise;
end Apply_Animation_Frame;
