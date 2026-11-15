with Ada.Finalization;
with Terminal.Common.Bytes;
with Terminal.Common.Base64;
with Terminal.Common.Graphics_Limits;
with Terminal.App.Graphics;
with Terminal.App.Graphics_Transport;
with Terminal.App.Image_Media;
with Terminal.App.Image_Store;
with Terminal.App.Render_Model;
with Terminal.Core;

package body Terminal.App.Image_Ingestion is
   use type Terminal.App.Graphics_Transport.Byte_Array_Access;
   use type Terminal.App.Graphics.ITerm2_Size_Unit;
   use type Terminal.App.Graphics.Graphics_Protocol;
   function Payload_Start
     (Protocol : Payload_Protocol;
      Text     : String) return Natural
   is
      Separator : constant Character :=
        (if Protocol = Kitty then ';' else ':');
   begin
      for I in Text'Range loop
         if Text (I) = Separator then
            return (if I < Text'Last then I + 1 else 0);
         end if;
      end loop;
      return 0;
   end Payload_Start;

   procedure Copy_Text
     (Text    : String;
      Control : in out Terminal.App.Image_Store.Allocation_Control;
      Result  : in out Terminal.App.Owned_Image_Data.Owner)
   is
      procedure Copy_Characters
        (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         for I in Text'Range loop
            Bytes (I - Text'First + 1) :=
              Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
         end loop;
      end Copy_Characters;
   begin
      if Text'Length = 0 then
         return;
      end if;

      if not Terminal.App.Image_Store.Allocation_Allowed (Control) then
         return;
      end if;

      Terminal.App.Owned_Image_Data.Allocate (Result, Text'Length);
      Terminal.App.Owned_Image_Data.Modify (Result, Copy_Characters'Access);
   exception
      when Storage_Error =>
         Terminal.App.Owned_Image_Data.Release (Result);
   end Copy_Text;

   procedure Copy_Compact_Base64
     (Text    : String;
      Control : in out Terminal.App.Image_Store.Allocation_Control;
      Result  : in out Terminal.App.Owned_Image_Data.Owner)
   is
      Length : Natural := 0;
   begin
      for Ch of Text loop
         if not Terminal.Common.Base64.Is_Whitespace (Ch) then
            Length := Length + 1;
         end if;
      end loop;
      if Length = 0
        or else not Terminal.App.Image_Store.Allocation_Allowed (Control)
      then
         return;
      end if;
      declare
         procedure Copy_Characters
           (Bytes : in out Terminal.Common.Bytes.Byte_Array)
         is
            Cursor : Natural := 0;
         begin
            for Ch of Text loop
               if not Terminal.Common.Base64.Is_Whitespace (Ch) then
                  Cursor := Cursor + 1;
                  Bytes (Cursor) :=
                    Terminal.Common.Bytes.Byte (Character'Pos (Ch));
               end if;
            end loop;
         end Copy_Characters;
      begin
         Terminal.App.Owned_Image_Data.Allocate (Result, Length);
         Terminal.App.Owned_Image_Data.Modify (Result, Copy_Characters'Access);
      end;
   exception
      when Storage_Error =>
         Terminal.App.Owned_Image_Data.Release (Result);
   end Copy_Compact_Base64;

   function Encode_Base64
     (Bytes  : Terminal.App.Graphics_Transport.Byte_Array_Access;
      Length : Natural) return String
   is
      Alphabet : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
   begin
      if Bytes = null or else Length = 0 or else Length > Bytes'Length then
         return "";
      end if;
      declare
         Block_Count : constant Natural :=
           Length / 3 + (if Length mod 3 = 0 then 0 else 1);
      begin
         if Block_Count > Natural'Last / 4 then
            return "";
         end if;
         declare
            Result : String (1 .. Block_Count * 4);
            Source : Natural := 1;
            Target : Natural := 1;
            A, B, C : Natural;
         begin
            while Source <= Length loop
               declare
                  Remaining : constant Positive := Length - Source + 1;
               begin
                  A := Natural (Bytes (Source));
                  B :=
                    (if Remaining >= 2
                     then Natural (Bytes (Source + 1))
                     else 0);
                  C :=
                    (if Remaining >= 3
                     then Natural (Bytes (Source + 2))
                     else 0);
                  Result (Target) := Alphabet (A / 4 + 1);
                  Result (Target + 1) :=
                    Alphabet ((A mod 4) * 16 + B / 16 + 1);
                  Result (Target + 2) :=
                    (if Remaining >= 2
                     then Alphabet ((B mod 16) * 4 + C / 64 + 1)
                     else '=');
                  Result (Target + 3) :=
                    (if Remaining >= 3
                     then Alphabet (C mod 64 + 1)
                     else '=');
                  exit when Remaining <= 3;
                  Source := Source + 3;
                  Target := Target + 4;
               end;
            end loop;
            return Result;
         end;
      end;
   end Encode_Base64;

   function ITerm2_Render_Size
     (Header           : Terminal.App.Graphics.Graphics_Header;
      Intrinsic_Width  : Positive;
      Intrinsic_Height : Positive;
      Cell_Width       : Positive;
      Cell_Height      : Positive;
      View_Width       : Natural;
      View_Height      : Natural) return Pixel_Size
   is
      function Requested
        (Specified : Boolean;
         Value     : Natural;
         Unit      : Terminal.App.Graphics.ITerm2_Size_Unit;
         Intrinsic : Positive;
         Cell_Size : Positive;
         View_Size : Natural) return Float is
      begin
         if not Specified
           or else Unit = Terminal.App.Graphics.ITerm2_Auto
         then
            return Float (Intrinsic);
         end if;
         case Unit is
            when Terminal.App.Graphics.ITerm2_Cells =>
               return Float (Value) * Float (Cell_Size);
            when Terminal.App.Graphics.ITerm2_Pixels =>
               return Float (Value);
            when Terminal.App.Graphics.ITerm2_Percent =>
               return Float (View_Size) * Float (Value) / 100.0;
            when Terminal.App.Graphics.ITerm2_Auto =>
               return Float (Intrinsic);
         end case;
      end Requested;

   begin
      if Header.Protocol /= Terminal.App.Graphics.ITerm2 then
         return
           (Width  => Float (Intrinsic_Width),
            Height => Float (Intrinsic_Height));
      end if;
      declare
         Box_Width : constant Float := Requested
           (Header.ITerm2_Width_Specified,
            Header.ITerm2_Width_Value,
            Header.ITerm2_Width_Unit,
            Intrinsic_Width,
            Cell_Width,
            View_Width);
         Box_Height : constant Float := Requested
           (Header.ITerm2_Height_Specified,
            Header.ITerm2_Height_Value,
            Header.ITerm2_Height_Unit,
            Intrinsic_Height,
            Cell_Height,
            View_Height);
         Scale : constant Float :=
           (if not Header.ITerm2_Preserve_Aspect_Ratio
            then 1.0
            elsif Header.ITerm2_Width_Specified
              and then Header.ITerm2_Height_Specified
            then Float'Min
              (Box_Width / Float (Intrinsic_Width),
               Box_Height / Float (Intrinsic_Height))
            elsif Header.ITerm2_Width_Specified
            then Box_Width / Float (Intrinsic_Width)
            elsif Header.ITerm2_Height_Specified
            then Box_Height / Float (Intrinsic_Height)
            else 1.0);
      begin
         return
           (Width => Float'Max
              (1.0,
               (if Header.ITerm2_Preserve_Aspect_Ratio
                then Float (Intrinsic_Width) * Scale
                else Box_Width)),
            Height => Float'Max
              (1.0,
               (if Header.ITerm2_Preserve_Aspect_Ratio
                then Float (Intrinsic_Height) * Scale
                else Box_Height)));
      end;
   end ITerm2_Render_Size;

   function Validate_Kitty_Query
     (Header        : Terminal.App.Graphics.Graphics_Header;
      Text          : String;
      Policy        : Terminal.App.Graphics_Transport.Access_Policy;
      Maximum_Bytes : Positive;
      Maximum_Pixel_Dimension : Positive :=
        Terminal.Common.Graphics_Limits.Max_Pixel_Dimension;
      Maximum_Frames : Positive :=
        Terminal.Common.Graphics_Limits.Max_Animation_Frames)
      return Terminal.Core.Graphics_Completion_Code
   is separate;
end Terminal.App.Image_Ingestion;
