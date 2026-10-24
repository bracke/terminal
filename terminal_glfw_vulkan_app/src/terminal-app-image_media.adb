with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

with Giflib;
with Giflib.Animations;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;
with Terminal.App.Platform_Media;

package body Terminal.App.Image_Media is
   package C renames Interfaces.C;
   package CS renames Interfaces.C.Strings;
   package RM renames Terminal.App.Render_Model;
   package Platform renames Terminal.App.Platform_Media;

   use type C.int;
   use type C.size_t;
   use type C.unsigned;
   use type CS.chars_ptr;
   use type Interfaces.Unsigned_64;
   use type Terminal.Common.Bytes.Byte;
   use type RM.Image_Data_Access;
   use type System.Address;
   use type Giflib.Animations.Loop_State;
   use type Giflib.Byte_Count;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Streams.Byte_Array_Access;

   Library_Handle : System.Address := System.Null_Address;
   Load_Attempted : Boolean := False;

   type String_Access is access all String;
   Libraries : constant array (Positive range <>) of String_Access :=
     [new String'("libMagickWand-7.Q16.so.10"),
      new String'("libMagickWand-7.Q16HDRI.so.10"),
      new String'("libMagickWand-7.Q16.so"),
      new String'("libMagickWand-6.Q16.so.7"),
      new String'("libMagickWand-6.Q16.so")];

   type Genesis_Access is access procedure
   with Convention => C;
   type New_Wand_Access is access function return System.Address
   with Convention => C;
   type Destroy_Wand_Access is access function
     (Wand : System.Address) return System.Address
   with Convention => C;
   type Read_Blob_Access is access function
     (Wand : System.Address;
      Blob : System.Address;
      Length : C.size_t) return C.unsigned
   with Convention => C;
   type Get_Size_Access is access function
     (Wand : System.Address) return C.size_t
   with Convention => C;
   type Set_Index_Access is access function
     (Wand : System.Address;
      Index : C.long) return C.unsigned
   with Convention => C;
   type Set_Format_Access is access function
     (Wand : System.Address;
      Format : CS.chars_ptr) return C.unsigned
   with Convention => C;
   type Export_Access is access function
     (Wand : System.Address;
      X, Y : C.long;
      Width, Height : C.size_t;
      Map : CS.chars_ptr;
      Storage : C.int;
      Pixels : System.Address) return C.unsigned
   with Convention => C;
   type Coalesce_Access is access function
     (Wand : System.Address) return System.Address
   with Convention => C;
   type Set_Limit_Access is access function
     (Resource : C.int;
      Limit : Interfaces.Unsigned_64) return C.unsigned
   with Convention => C;

   function To_Genesis is new Ada.Unchecked_Conversion
     (System.Address, Genesis_Access);
   function To_New_Wand is new Ada.Unchecked_Conversion
     (System.Address, New_Wand_Access);
   function To_Destroy is new Ada.Unchecked_Conversion
     (System.Address, Destroy_Wand_Access);
   function To_Read is new Ada.Unchecked_Conversion
     (System.Address, Read_Blob_Access);
   function To_Get_Size is new Ada.Unchecked_Conversion
     (System.Address, Get_Size_Access);
   function To_Set_Index is new Ada.Unchecked_Conversion
     (System.Address, Set_Index_Access);
   function To_Set_Format is new Ada.Unchecked_Conversion
     (System.Address, Set_Format_Access);
   function To_Export is new Ada.Unchecked_Conversion
     (System.Address, Export_Access);
   function To_Coalesce is new Ada.Unchecked_Conversion
     (System.Address, Coalesce_Access);
   function To_Set_Limit is new Ada.Unchecked_Conversion
     (System.Address, Set_Limit_Access);

   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, RM.Image_Data_Access);
   procedure Free_GIF_Data is new Ada.Unchecked_Deallocation
     (Giflib.Streams.Byte_Array, Giflib.Streams.Byte_Array_Access);

   procedure Ensure_Loaded is
   begin
      if Load_Attempted then
         return;
      end if;
      Load_Attempted := True;
      for Name of Libraries loop
         Library_Handle := Platform.Open_Dynamic_Library (Name.all);
         exit when Library_Handle /= System.Null_Address;
      end loop;
   end Ensure_Loaded;

   function Symbol (Name : String) return System.Address is
   begin
      Ensure_Loaded;
      if Library_Handle = System.Null_Address then
         return System.Null_Address;
      end if;
      return Platform.Dynamic_Symbol (Library_Handle, Name);
   end Symbol;

   function Extended_Media_Available return Boolean is
   begin
      Ensure_Loaded;
      return Library_Handle /= System.Null_Address
        and then Symbol ("NewMagickWand") /= System.Null_Address
        and then Symbol ("MagickReadImageBlob") /= System.Null_Address
        and then Symbol ("MagickExportImagePixels") /= System.Null_Address;
   end Extended_Media_Available;

   function Available return Boolean is (True);

   function Is_GIF
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
      Signature : String (1 .. 6);
   begin
      if Length < 6 or else Length > Data'Length then
         return False;
      end if;
      for I in Signature'Range loop
         Signature (I) := Character'Val (Data (Data'First + I - 1));
      end loop;
      return Signature in "GIF87a" | "GIF89a";
   end Is_GIF;

   function Is_PDF
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
      Signature : constant String := "%PDF-";
   begin
      if Length < Signature'Length or else Length > Data'Length then
         return False;
      end if;
      for I in Signature'Range loop
         if Data (Data'First + I - Signature'First) /=
           Terminal.Common.Bytes.Byte (Character'Pos (Signature (I)))
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_PDF;

   function Is_Headered_PICT
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
   begin
      --  Classic PICT files commonly carry a 512-byte all-zero file header.
      --  The image rectangle immediately following it must have increasing
      --  bottom/right coordinates.  Supplying the coder explicitly is needed
      --  because MagickWand cannot reliably identify this header from a blob.
      if Length < 522 or else Length > Data'Length then
         return False;
      end if;
      for Offset in 0 .. 511 loop
         if Data (Data'First + Offset) /= 0 then
            return False;
         end if;
      end loop;
      return
        (Natural (Data (Data'First + 516)) * 256
         + Natural (Data (Data'First + 517)))
        <
        (Natural (Data (Data'First + 520)) * 256
         + Natural (Data (Data'First + 521)))
        and then
        (Natural (Data (Data'First + 514)) * 256
         + Natural (Data (Data'First + 515)))
        <
        (Natural (Data (Data'First + 518)) * 256
         + Natural (Data (Data'First + 519)));
   end Is_Headered_PICT;

   function GIF_Loop_Count
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Natural
   is
      Marker : constant String := "NETSCAPE2.0";
   begin
      if Length < Marker'Length + 5 or else Length > Data'Length then
         --  No looping extension means play the animation exactly once.
         return 0;
      end if;
      for Offset in 0 .. Length - Marker'Length - 5 loop
         declare
            Matches : Boolean := True;
            First : constant Positive := Data'First + Offset;
         begin
            for I in Marker'Range loop
               if Data (First + I - Marker'First) /=
                 Terminal.Common.Bytes.Byte (Character'Pos (Marker (I)))
               then
                  Matches := False;
                  exit;
               end if;
            end loop;
            if Matches
              and then Data (First + Marker'Length) = 3
              and then Data (First + Marker'Length + 1) = 1
            then
               declare
                  Loops : constant Natural :=
                    Natural (Data (First + Marker'Length + 2))
                    + 256 * Natural (Data (First + Marker'Length + 3));
               begin
                  --  The GIF extension counts repeats after the initial play.
                  --  The renderer uses one as its infinite-loop sentinel and
                  --  values above one as a total number of plays.
                  return (if Loops = 0 then 1 else Loops + 1);
               end;
            end if;
         end;
      end loop;
      return 0;
   end GIF_Loop_Count;

   procedure Release (Result : in out Decoded_Image) is
   begin
      if Result.Bytes /= null then
         Free_Image_Data (Result.Bytes);
      end if;
      Result := (others => <>);
   end Release;

   procedure Decode_GIF
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status)
   is
      Input : Giflib.Streams.Byte_Array_Access := null;
      Canvas : Giflib.Streams.Byte_Array_Access := null;
      Source : aliased Giflib.Streams.Memory_Source;
      Decoder : Giflib.Decoding.Decoder;
      Options : Giflib.Decoding.Decode_Options :=
        Giflib.Decoding.Default_Options;
      Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
      Header : Giflib.Decoding.Header_Info;
      Event : Giflib.Decoding.Decode_Event;
      Info : Giflib.Decoding.Frame_Info;
      Outcome : Giflib.Results.Result;
      Looping : Giflib.Animations.Loop_Info := Giflib.Animations.No_Loop;
      Frame_Count : Natural := 0;
      Decoded_Frames : Natural := 0;
      Width : Natural := 0;
      Height : Natural := 0;
      Pixel_Count : Natural := 0;
      Frame_Bytes : Natural := 0;
      Total_Bytes : Natural := 0;
      Decoder_Initialized : Boolean := False;

      function Bounded_Multiple
        (Value  : Natural;
         Factor : Positive) return Giflib.Byte_Count
      is
      begin
         if Giflib.Byte_Count (Value) >
           Giflib.Byte_Count'Last / Giflib.Byte_Count (Factor)
         then
            return Giflib.Byte_Count'Last;
         end if;
         return Giflib.Byte_Count (Value) * Giflib.Byte_Count (Factor);
      end Bounded_Multiple;

      procedure Clean_Up is
      begin
         if Decoder_Initialized then
            Giflib.Decoding.Finalize (Decoder);
            Decoder_Initialized := False;
         end if;
         if Canvas /= null then
            Free_GIF_Data (Canvas);
         end if;
         if Input /= null then
            Free_GIF_Data (Input);
         end if;
      end Clean_Up;

      procedure Fail (Failure : Giflib.Results.Result) is
      begin
         Release (Result);
         Status :=
           (if Failure.First_Error.Code in
                  Giflib.Errors.Limit_Exceeded | Giflib.Errors.Integer_Overflow
            then Decode_Too_Large
            else Decode_Invalid);
         Clean_Up;
      end Fail;
   begin
      Release (Result);
      Status := Decode_Invalid;
      if Length = 0 or else Length > Data'Length then
         return;
      end if;

      Input := new Giflib.Streams.Byte_Array (1 .. Length);
      for I in 1 .. Length loop
         Input (I) := Giflib.Byte (Data (Data'First + I - 1));
      end loop;

      Constraints.Max_Logical_Width :=
        Giflib.Image_Width
          (Natural'Min (Maximum_Pixel_Dimension,
                        Natural (Giflib.Image_Width'Last)));
      Constraints.Max_Logical_Height :=
        Giflib.Image_Height
          (Natural'Min (Maximum_Pixel_Dimension,
                        Natural (Giflib.Image_Height'Last)));
      Constraints.Max_Canvas_Pixels :=
        Giflib.Pixel_Count (Maximum_Decoded_Bytes / 4);
      Constraints.Max_Canvas_Bytes :=
        Giflib.Byte_Count (Maximum_Decoded_Bytes);
      Constraints.Max_Frames := Giflib.Frame_Ordinal (Max_Frames);
      Constraints.Max_Frame_Pixels :=
        Giflib.Pixel_Count (Maximum_Decoded_Bytes / 4);
      Constraints.Max_Total_Decoded_Frame_Pixels :=
        Giflib.Pixel_Count (Maximum_Decoded_Bytes / 4);
      Constraints.Max_Compressed_Bytes := Giflib.Byte_Count (Length);
      Constraints.Max_Allocation_Bytes :=
        Bounded_Multiple (Maximum_Decoded_Bytes, 3);
      Constraints.Max_Output_Bytes :=
        Giflib.Byte_Count (Maximum_Decoded_Bytes);
      Constraints.Max_LZW_Work :=
        Bounded_Multiple (Maximum_Decoded_Bytes, 16);
      Constraints.Max_Compositor_Snapshot_Bytes :=
        Giflib.Byte_Count (Maximum_Decoded_Bytes);

      --  Count frames first so the public result owns an exact-size bounded
      --  allocation. This pass skips compressed image data and also discovers
      --  the authoritative loop extension.
      Options.Mode := Giflib.Decoding.Raw_Indexed;
      Giflib.Streams.Open (Source, Input.all'Unchecked_Access);
      Outcome :=
        Giflib.Decoding.Initialize
          (Decoder, Source'Unchecked_Access, Options, Constraints);
      Decoder_Initialized := Giflib.Results.Succeeded (Outcome);
      if not Decoder_Initialized then
         Fail (Outcome);
         return;
      end if;
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      if not Giflib.Results.Succeeded (Outcome) then
         Fail (Outcome);
         return;
      end if;
      Width := Natural (Header.Width);
      Height := Natural (Header.Height);
      loop
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         if not Giflib.Results.Succeeded (Outcome) then
            Fail (Outcome);
            return;
         elsif Event.Kind = Giflib.Decoding.End_Event then
            exit;
         elsif Event.Kind = Giflib.Decoding.Image_Event then
            Frame_Count := Frame_Count + 1;
            if Frame_Count > Max_Frames then
               Release (Result);
               Status := Decode_Too_Large;
               Clean_Up;
               return;
            end if;
            Outcome := Giflib.Decoding.Skip_Frame (Decoder);
            if not Giflib.Results.Succeeded (Outcome) then
               Fail (Outcome);
               return;
            end if;
         end if;
      end loop;
      Looping := Giflib.Decoding.Looping (Decoder);
      if Frame_Count = 0
        or else Width = 0
        or else Height = 0
        or else Width > Maximum_Pixel_Dimension
        or else Height > Maximum_Pixel_Dimension
        or else Width > Natural'Last / Height
      then
         Release (Result);
         Status := Decode_Too_Large;
         Clean_Up;
         return;
      end if;
      Pixel_Count := Width * Height;
      if Pixel_Count > Natural'Last / 4 then
         Release (Result);
         Status := Decode_Too_Large;
         Clean_Up;
         return;
      end if;
      Frame_Bytes := Pixel_Count * 4;
      if Frame_Bytes = 0
        or else Frame_Count > Maximum_Decoded_Bytes / Frame_Bytes
      then
         Release (Result);
         Status := Decode_Too_Large;
         Clean_Up;
         return;
      end if;
      Total_Bytes := Frame_Count * Frame_Bytes;
      Result.Bytes :=
        new Terminal.Common.Bytes.Byte_Array (1 .. Total_Bytes);
      Canvas := new Giflib.Streams.Byte_Array (1 .. Frame_Bytes);

      --  Decode composited logical canvases so disposal and transparency are
      --  already resolved for the renderer's frame playback model.
      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Giflib.Streams.Open (Source, Input.all'Unchecked_Access);
      Outcome :=
        Giflib.Decoding.Reset
          (Decoder, Source'Unchecked_Access, Options, Constraints);
      if not Giflib.Results.Succeeded (Outcome) then
         Fail (Outcome);
         return;
      end if;
      Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
      if not Giflib.Results.Succeeded (Outcome)
        or else Natural (Header.Width) /= Width
        or else Natural (Header.Height) /= Height
      then
         if Giflib.Results.Succeeded (Outcome) then
            Outcome := Giflib.Results.Failure (Giflib.Errors.Invalid_Dimensions);
         end if;
         Fail (Outcome);
         return;
      end if;

      loop
         Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
         if not Giflib.Results.Succeeded (Outcome) then
            Fail (Outcome);
            return;
         elsif Event.Kind = Giflib.Decoding.End_Event then
            exit;
         elsif Event.Kind = Giflib.Decoding.Image_Event then
            if Decoded_Frames = Frame_Count then
               Release (Result);
               Status := Decode_Invalid;
               Clean_Up;
               return;
            end if;
            Outcome :=
              Giflib.Decoding.Decode_Composited_Frame
                (Decoder, Canvas.all, Info);
            if not Giflib.Results.Succeeded (Outcome) then
               Fail (Outcome);
               return;
            end if;
            Decoded_Frames := Decoded_Frames + 1;
            declare
               First : constant Positive :=
                 Result.Bytes'First + (Decoded_Frames - 1) * Frame_Bytes;
            begin
               for I in 0 .. Frame_Bytes - 1 loop
                  Result.Bytes (First + I) :=
                    Terminal.Common.Bytes.Byte (Canvas (Canvas'First + I));
               end loop;
            end;
            Result.Delays_MS (Decoded_Frames) :=
              Natural'Max (10, Natural (Info.Control.Delay_CS) * 10);
         end if;
      end loop;
      if Decoded_Frames /= Frame_Count then
         Release (Result);
         Status := Decode_Invalid;
         Clean_Up;
         return;
      end if;

      Result.Pixel_Width := Width;
      Result.Pixel_Height := Height;
      Result.Frame_Count := Frame_Count;
      Result.Loop_Count :=
        (case Looping.State is
            when Giflib.Animations.No_Loop_Extension => 0,
            when Giflib.Animations.Infinite_Looping => 1,
            when Giflib.Animations.Finite_Loop_Count =>
              Looping.Raw_Count + 1);
      Result.Frame_Bytes := Frame_Bytes;
      Result.Total_Bytes := Total_Bytes;
      Status := Decode_Ok;
      Clean_Up;
   exception
      when Storage_Error =>
         Release (Result);
         Clean_Up;
         Status := Decode_Allocation_Failed;
      when others =>
         Release (Result);
         Clean_Up;
         Status := Decode_Invalid;
   end Decode_GIF;

   procedure Decode
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status)
   is
      Genesis : Genesis_Access;
      New_Wand : New_Wand_Access;
      Destroy : Destroy_Wand_Access;
      Read_Blob : Read_Blob_Access;
      Get_Count : Get_Size_Access;
      Get_Width : Get_Size_Access;
      Get_Height : Get_Size_Access;
      Get_Delay : Get_Size_Access;
      Set_Index : Set_Index_Access;
      Set_Format : Set_Format_Access;
      Export_Pixels : Export_Access;
      Coalesce : Coalesce_Access;
      Set_Limit : Set_Limit_Access;
      Wand : System.Address := System.Null_Address;
      Frames_Wand : System.Address := System.Null_Address;
      Is_Animation : constant Boolean := Is_GIF (Data, Length);
      Frame_Count : Natural := 1;
      Width : Natural := 0;
      Height : Natural := 0;
      Frame_Bytes : Natural := 0;
      Total_Bytes : Natural := 0;
      Map : CS.chars_ptr := CS.Null_Ptr;

      procedure Destroy_All is
         Ignored : System.Address;
      begin
         if Map /= CS.Null_Ptr then
            CS.Free (Map);
            Map := CS.Null_Ptr;
         end if;
         if Destroy /= null then
            if Frames_Wand /= System.Null_Address and then Frames_Wand /= Wand then
               Ignored := Destroy (Frames_Wand);
               Frames_Wand := System.Null_Address;
            end if;
            if Wand /= System.Null_Address then
               Ignored := Destroy (Wand);
               Wand := System.Null_Address;
            end if;
         end if;
      end Destroy_All;

      function Required (Name : String) return System.Address is
      begin
         return Symbol (Name);
      end Required;
   begin
      Release (Result);
      Status := Decode_Unavailable;
      if Length = 0 or else Length > Data'Length then
         return;
      elsif Is_GIF (Data, Length) then
         Decode_GIF
           (Data,
            Length,
            Maximum_Decoded_Bytes,
            Maximum_Pixel_Dimension,
            Result,
            Status);
         return;
      elsif not Extended_Media_Available then
         return;
      end if;

      Genesis := To_Genesis (Required ("MagickWandGenesis"));
      New_Wand := To_New_Wand (Required ("NewMagickWand"));
      Destroy := To_Destroy (Required ("DestroyMagickWand"));
      Read_Blob := To_Read (Required ("MagickReadImageBlob"));
      Get_Count := To_Get_Size (Required ("MagickGetNumberImages"));
      Get_Width := To_Get_Size (Required ("MagickGetImageWidth"));
      Get_Height := To_Get_Size (Required ("MagickGetImageHeight"));
      Get_Delay := To_Get_Size (Required ("MagickGetImageDelay"));
      Set_Index := To_Set_Index (Required ("MagickSetIteratorIndex"));
      Set_Format := To_Set_Format (Symbol ("MagickSetFormat"));
      Export_Pixels := To_Export (Required ("MagickExportImagePixels"));
      Coalesce := To_Coalesce (Required ("MagickCoalesceImages"));
      Set_Limit := To_Set_Limit (Symbol ("MagickSetResourceLimit"));
      if Genesis = null or else New_Wand = null or else Destroy = null
        or else Read_Blob = null or else Get_Count = null
        or else Get_Width = null or else Get_Height = null
        or else Get_Delay = null or else Set_Index = null
        or else Export_Pixels = null or else Coalesce = null
      then
         return;
      end if;

      Genesis.all;
      if Set_Limit /= null then
         declare
            Ignored : C.unsigned;
            Byte_Limit : constant Interfaces.Unsigned_64 :=
              Interfaces.Unsigned_64 (Maximum_Decoded_Bytes);
            Dimension_Limit : constant Interfaces.Unsigned_64 :=
              Interfaces.Unsigned_64 (Maximum_Pixel_Dimension);
         begin
            Ignored := Set_Limit (1, Byte_Limit / 4); -- area
            Ignored := Set_Limit (2, 0);              -- disk
            Ignored := Set_Limit (4, Byte_Limit);     -- map
            Ignored := Set_Limit (5, Byte_Limit);     -- memory
            Ignored := Set_Limit (7, 5);              -- seconds
            Ignored := Set_Limit (9, Dimension_Limit);
            Ignored := Set_Limit (10, Dimension_Limit);
            Ignored := Set_Limit (11, Max_Frames);
            pragma Unreferenced (Ignored);
         end;
      end if;

      Wand := New_Wand.all;
      if Wand = System.Null_Address then
         Status := Decode_Invalid;
         Destroy_All;
         return;
      end if;
      if Is_PDF (Data, Length) or else Is_Headered_PICT (Data, Length) then
         if Set_Format = null then
            Status := Decode_Unavailable;
            Destroy_All;
            return;
         end if;
         declare
            Hint : CS.chars_ptr :=
              CS.New_String
                ((if Is_PDF (Data, Length) then "PDF" else "PICT"));
            Accepted : constant C.unsigned := Set_Format (Wand, Hint);
         begin
            CS.Free (Hint);
            if Accepted = 0 then
               Status := Decode_Invalid;
               Destroy_All;
               return;
            end if;
         end;
      end if;
      if Read_Blob (Wand, Data (Data'First)'Address, C.size_t (Length)) = 0 then
         Status := Decode_Invalid;
         Destroy_All;
         return;
      end if;

      Frames_Wand := Wand;
      if Is_Animation then
         Frames_Wand := Coalesce (Wand);
         if Frames_Wand = System.Null_Address then
            Status := Decode_Invalid;
            Destroy_All;
            return;
         end if;
         declare
            Actual_Frame_Count : constant Natural :=
              Natural (Get_Count (Frames_Wand));
         begin
            if Actual_Frame_Count > Max_Frames then
               Status := Decode_Too_Large;
               Destroy_All;
               return;
            end if;
            Frame_Count := Actual_Frame_Count;
         end;
      end if;
      if Frame_Count = 0 or else Set_Index (Frames_Wand, 0) = 0 then
         Status := Decode_Invalid;
         Destroy_All;
         return;
      end if;
      Width := Natural (Get_Width (Frames_Wand));
      Height := Natural (Get_Height (Frames_Wand));
      if Width = 0 or else Height = 0
        or else Width > Maximum_Pixel_Dimension
        or else Height > Maximum_Pixel_Dimension
        or else Width > Natural'Last / Height
        or else Width * Height > Natural'Last / 4
      then
         Status := Decode_Too_Large;
         Destroy_All;
         return;
      end if;
      Frame_Bytes := Width * Height * 4;
      if Frame_Count > Maximum_Decoded_Bytes / Frame_Bytes then
         Status := Decode_Too_Large;
         Destroy_All;
         return;
      end if;
      Total_Bytes := Frame_Count * Frame_Bytes;
      Result.Bytes := new Terminal.Common.Bytes.Byte_Array (1 .. Total_Bytes);
      Map := CS.New_String ("RGBA");
      for Frame in 1 .. Frame_Count loop
         if Set_Index (Frames_Wand, C.long (Frame - 1)) = 0
           or else Natural (Get_Width (Frames_Wand)) /= Width
           or else Natural (Get_Height (Frames_Wand)) /= Height
           or else Export_Pixels
             (Frames_Wand,
              0,
              0,
              C.size_t (Width),
              C.size_t (Height),
              Map,
              1,
              Result.Bytes (Result.Bytes'First + (Frame - 1) * Frame_Bytes)'Address) = 0
         then
            Release (Result);
            Status := Decode_Invalid;
            Destroy_All;
            return;
         end if;
         Result.Delays_MS (Frame) :=
           Natural'Max (10, Natural (Get_Delay (Frames_Wand)) * 10);
      end loop;

      Result.Pixel_Width := Width;
      Result.Pixel_Height := Height;
      Result.Frame_Count := Frame_Count;
      Result.Loop_Count :=
        (if Is_Animation then GIF_Loop_Count (Data, Length) else 1);
      Result.Frame_Bytes := Frame_Bytes;
      Result.Total_Bytes := Total_Bytes;
      Status := Decode_Ok;
      Destroy_All;
   exception
      when Storage_Error =>
         Release (Result);
         Destroy_All;
         Status := Decode_Allocation_Failed;
      when others =>
         Release (Result);
         Destroy_All;
         Status := Decode_Invalid;
   end Decode;
end Terminal.App.Image_Media;
