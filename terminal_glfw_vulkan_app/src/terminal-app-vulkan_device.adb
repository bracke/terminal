with Ada.Exceptions;
with Interfaces;
with Ada.Unchecked_Deallocation;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with System.Address_To_Access_Conversions;
with Terminal.Common.Bytes;
with Terminal.Common.C_Strings;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Image_Staging;
with Terminal.App.Image_Upload_Layout;
with Terminal.App.Shaders;
with Terminal.App.Vulkan_Retirement;
with Terminal.App.Vulkan_Unmap_Once;
with Terminal.App.Vulkan_Destroy_Once;
with Terminal.App.Vulkan_Destroy_Pair;
with Terminal.App.Vulkan_Destroy_Triple;
with Terminal.App.Vulkan_Device.Selection_Logic;
with Terminal.App.Vulkan_Device.Resource_Lifecycle;
with Terminal.App.Vulkan_Device.Snapshots;
with Terminal.App.Vulkan_Enumeration;
with Terminal.App.Vulkan_Creation_Plan;

package body Terminal.App.Vulkan_Device is
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;
   use type Interfaces.C.char;
   use type Interfaces.C.Strings.chars_ptr;
   use type System.Address;
   use type Vk.Color_Space_KHR_T;
   use type Vk.Command_Pool_T;
   use type Vk.Command_Buffer_T;
   use type Vk.Composite_Alpha_Flags_KHR_T;
   use type Vk.Buffer_T;
   use type Vk.Device_T;
   use type Vk.Device_Memory_T;
   use type Vk.Descriptor_Pool_T;
   use type Vk.Descriptor_Set_T;
   use type Vk.Descriptor_Set_Layout_T;
   use type Vk.Fence_T;
   use type Vk.Format_T;
   use type Vk.Framebuffer_T;
   use type Vk.Image_T;
   use type Vk.Image_View_T;
   use type Vk.Image_Usage_Flags_T;
   use type Vk.Memory_Property_Flags_T;
   use type Vk.Pipeline_T;
   use type Vk.Pipeline_Layout_T;
   use type Vk.Present_Mode_KHR_T;
   use type Vk.Queue_Flags_T;
   use type Vk.Queue_T;
   use type Vk.Render_Pass_T;
   use type Vk.Result_T;
   use type Vk.Sample_Count_Flags_T;
   use type Vk.Sample_Count_Flag_Bits_T;
   use type Vk.Sampler_T;
   use type Vk.Semaphore_T;
   use type Vk.Surface_Transform_Flags_KHR_T;
   use type Vk.Swapchain_KHR_T;

   package RM renames Terminal.App.Render_Model;
   use type RM.Image_Decoded_Source_Kind;
   use type Terminal.App.Image_Staging.Decode_Status;
   use type Terminal.App.Image_Upload_Layout.Layout_Status;

   package VC renames Terminal.App.Vulkan_Context;
   package Shaders renames Terminal.App.Shaders;
   package VS renames Terminal.App.Vulkan_Submit;

   use type Shaders.Load_Status;
   use type VS.Texture_Source;

   subtype Shader_Stage_Range is Positive range 1 .. 2;
   subtype Vertex_Attribute_Range is Positive range 1 .. 5;
   subtype Dynamic_State_Range is Positive range 1 .. 2;

   Swapchain_Create_Info_Structure : constant Vk.Structure_Type_T :=
     Vk.Structure_Type_T (1_000_001_000);
   Present_Info_Structure : constant Vk.Structure_Type_T :=
     Vk.Structure_Type_T (1_000_001_008);
   Image_Layout_Present_Source : constant Vk.Image_Layout_T :=
     Vk.Image_Layout_T (1_000_001_002);
   Format_R8G8B8A8_Unorm : constant Vk.Format_T := Vk.Format_T (37);
   Format_R8_Unorm : constant Vk.Format_T := Vk.Format_T (9);
   Suboptimal_KHR : constant Vk.Result_T := Vk.Result_T (1_000_001_003);
   Error_Out_Of_Date_KHR : constant Vk.Result_T := Vk.Result_T (-1_000_001_004);
   Subpass_External : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32'Last;
   UInt32_Max : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32'Last;
   Packed_Vertex_Bytes : constant Interfaces.Unsigned_64 := 40;
   Max_Atlas_Bytes : constant := 16 * 1024 * 1024;
   Max_Image_Texture_Bytes : constant :=
     VS.Max_Image_Atlas_Bytes;
   Max_Framebuffer_Readback_Bytes : constant := 256 * 1024 * 1024;
   Queue_Family_Ignored : constant Interfaces.Unsigned_32 :=
     Interfaces.Unsigned_32'Last;

   type Readback_Byte_Array is array
     (Positive range 1 .. Max_Framebuffer_Readback_Bytes) of
       aliased Interfaces.Unsigned_8
     with Convention => C;
   package Readback_Byte_Conversions is new System.Address_To_Access_Conversions
     (Readback_Byte_Array);

   type Surface_Format_Array is
     array (Positive range <>) of Vk.Surface_Format_KHR_T
     with Convention => C;
   type Present_Mode_Array is
     array (Positive range <>) of Vk.Present_Mode_KHR_T
     with Convention => C;
   type Surface_Format_Array_Access is access Surface_Format_Array;
   type Present_Mode_Array_Access is access Present_Mode_Array;
   procedure Free_Surface_Formats is new Ada.Unchecked_Deallocation
     (Surface_Format_Array, Surface_Format_Array_Access);
   procedure Free_Present_Modes is new Ada.Unchecked_Deallocation
     (Present_Mode_Array, Present_Mode_Array_Access);
   function Fits_Natural (Value : Interfaces.Unsigned_32) return Boolean is
     (Interfaces.Unsigned_64 (Value) <=
        Interfaces.Unsigned_64 (Natural'Last));
   type Shader_Stage_Array is
     array (Shader_Stage_Range) of Vk.Pipeline_Shader_Stage_Create_Info_T
     with Convention => C;
   type Vertex_Attribute_Array is
     array (Vertex_Attribute_Range) of Vk.Vertex_Input_Attribute_Description_T
     with Convention => C;
   type Dynamic_State_Array is array (Dynamic_State_Range) of Vk.Dynamic_State_T
     with Convention => C;
   type Attachment_Array is
     array (Positive range <>) of Vk.Attachment_Description_T
     with Convention => C;
   type Image_View_Array is array (Positive range <>) of Vk.Image_View_T
     with Convention => C;
   type Buffer_Binding_Array is array (Positive range 1 .. 1) of Vk.Buffer_T
     with Convention => C;
   type Device_Size_Array is array (Positive range 1 .. 1) of Interfaces.Unsigned_64
     with Convention => C;
   type Command_Buffer_Submit_Array is
     array (Positive range 1 .. 1) of Vk.Command_Buffer_T
     with Convention => C;
   type Semaphore_Submit_Array is array (Positive range 1 .. 1) of Vk.Semaphore_T
     with Convention => C;
   type Pipeline_Stage_Array is
     array (Positive range 1 .. 1) of Vk.Pipeline_Stage_Flags_T
     with Convention => C;
   type Swapchain_Submit_Array is array (Positive range 1 .. 1) of Vk.Swapchain_KHR_T
     with Convention => C;
   type Image_Index_Array is array (Positive range 1 .. 1) of Interfaces.Unsigned_32
     with Convention => C;
   type Descriptor_Set_Layout_Array is
     array (Positive range 1 .. 1) of Vk.Descriptor_Set_Layout_T
     with Convention => C;
   type Descriptor_Pool_Size_Array is
     array (Positive range 1 .. 1) of Vk.Descriptor_Pool_Size_T
     with Convention => C;
   type Descriptor_Set_Layout_Binding_Array is
     array (Positive range 1 .. 3) of Vk.Descriptor_Set_Layout_Binding_T
     with Convention => C;
   type Image_Texture_Byte_Array is
     array (Positive range 1 .. Max_Image_Texture_Bytes) of Interfaces.Unsigned_8
     with Convention => C;
   type Byte_Array is array (Positive range 1 .. Max_Atlas_Bytes)
     of Interfaces.Unsigned_8
     with Convention => C;
   type Packed_Vertex is record
      X          : Interfaces.C.C_float := 0.0;
      Y          : Interfaces.C.C_float := 0.0;
      U          : Interfaces.C.C_float := 0.0;
      V          : Interfaces.C.C_float := 0.0;
      R          : Interfaces.C.C_float := 0.0;
      G          : Interfaces.C.C_float := 0.0;
      B          : Interfaces.C.C_float := 0.0;
      A          : Interfaces.C.C_float := 1.0;
      Textured   : Interfaces.C.C_float := 0.0;
      Texture_ID : Interfaces.C.C_float := 0.0;
   end record
     with Convention => C;
   type Packed_Vertex_Array is array (Positive range 1 .. Max_Upload_Vertices)
     of Packed_Vertex
     with Convention => C;
   package Vertex_Mapping is new System.Address_To_Access_Conversions
     (Packed_Vertex_Array);
   package Byte_Mapping is new System.Address_To_Access_Conversions
     (Byte_Array);
   package Image_Texture_Byte_Mapping is new System.Address_To_Access_Conversions
     (Image_Texture_Byte_Array);
   use type Byte_Mapping.Object_Pointer;
   use type Image_Texture_Byte_Mapping.Object_Pointer;

   type Chars_Ptr_Array is array (Positive range <>) of Interfaces.C.Strings.chars_ptr
     with Convention => C;

   function U32_Min (Left, Right : Interfaces.Unsigned_32)
                     return Interfaces.Unsigned_32 is
   begin
      if Left < Right then
         return Left;
      end if;
      return Right;
   end U32_Min;

   function U32_Max (Left, Right : Interfaces.Unsigned_32)
                     return Interfaces.Unsigned_32 is
   begin
      if Left > Right then
         return Left;
      end if;
      return Right;
   end U32_Max;

   function Clamp_U32
     (Value : Interfaces.Unsigned_32;
      Low   : Interfaces.Unsigned_32;
      High  : Interfaces.Unsigned_32)
      return Interfaces.Unsigned_32 is
   begin
      return U32_Min (U32_Max (Value, Low), High);
   end Clamp_U32;

   function To_Float (Value : Boolean) return Interfaces.C.C_float is
   begin
      if Value then
         return 1.0;
      end if;
      return 0.0;
   end To_Float;

   function Texture_ID
     (Source : VS.Texture_Source) return Interfaces.C.C_float
   is
   begin
      case Source is
         when VS.Texture_None =>
            return 0.0;
         when VS.Texture_Text_Atlas =>
            return 1.0;
         when VS.Texture_Image =>
            return 2.0;

         --  Matches the shader's third branch, frag_texture_id > 2.5.
         when VS.Texture_Colour_Glyphs =>
            return 3.0;
      end case;
   end Texture_ID;


   function Is_Swapchain_Stale (Result : Vk.Result_T) return Boolean is
     (Result = Suboptimal_KHR or else Result = Error_Out_Of_Date_KHR);

   procedure Destroy_Atlas_Image (Device : in out Logical_Device);
   procedure Destroy_Image_Texture (Device : in out Logical_Device);
   procedure Destroy_Colour_Sheet (Device : in out Logical_Device);
   procedure Destroy_Readback_Buffer
     (Device  : in out Logical_Device;
      Success : out Boolean);
   procedure Destroy_Deferred_Upload
     (Device  : in out Logical_Device;
      Success : out Boolean);

   --  Restore every owning handle and diagnostic field to its declared
   --  default.  Creation rollback and controlled finalization share this one
   --  reset path so newly added state cannot drift between them.
   procedure Reset_State
     (Device       : in out Logical_Device;
      Status_Value : Create_Status) is separate;

   procedure Defer_Upload_Resources
     (Device         : in out Logical_Device;
      Staging_Buffer : in out Vk.Buffer_T;
      Staging_Memory : in out Vk.Device_Memory_T;
      Image          : in out Vk.Image_T;
      Image_Memory   : in out Vk.Device_Memory_T;
      Image_View     : in out Vk.Image_View_T);

   procedure Reap_Deferred_Upload
     (Device : in out Logical_Device;
      Ready  : out Boolean;
      Status : out Create_Status);

   procedure Restore_Upload_Fence
     (Device : in out Logical_Device;
      Status : out Create_Status);

   --  One transparent pixel, for the colour sheet before any emoji exists.
   type Blank_Pixel is array (1 .. 4) of Interfaces.Unsigned_8;
   pragma Convention (C, Blank_Pixel);

   type Texture_Slot is (Text_Glyphs, Inline_Picture, Colour_Glyphs);

   procedure Upload_Image_Texture_Staging_Source
     (Device        : in out Logical_Device;
      Slot          : Texture_Slot;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Source_Bytes_Per_Pixel : Natural;
      Row_Stride_Bytes : Natural;
      Bytes_Natural : Natural;
      Fill_Staging  : not null access procedure
        (Target   : Image_Texture_Byte_Mapping.Object_Pointer;
         Capacity : Positive;
         Status : out Create_Status);
      Status        : out Create_Status;
      Image_Format  : Vk.Format_T := Format_R8G8B8A8_Unorm;
      Maximum_Bytes : Positive := Max_Image_Texture_Bytes;
      Content_Signature : Interfaces.Unsigned_64 := 0);

   procedure Upload_Atlas_Data
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Bytes_Natural : Natural;
      Pixels        : System.Address;
      Dirty         : Boolean;
      Status        : out Create_Status);

   procedure Upload_Image_Texture_Data
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Bytes_Natural : Natural;
      Pixels        : System.Address;
      Status        : out Create_Status;
      Slot          : Texture_Slot := Inline_Picture);

   procedure Upload_Image_Texture_Rows
     (Device           : in out Logical_Device;
      Choice           : Selection;
      Width            : Natural;
      Height           : Natural;
      Source_Bytes_Per_Pixel : Natural;
      Row_Stride_Bytes : Natural;
      Bytes_Natural    : Natural;
      Pixels           : System.Address;
      Status           : out Create_Status;
      Slot             : Texture_Slot := Inline_Picture);

   function Has_Memory_Type
     (Properties : Vk.Physical_Device_Memory_Properties_T;
      Bits       : Interfaces.Unsigned_32;
      Flags      : Vk.Memory_Property_Flags_T;
      Index      : out Interfaces.Unsigned_32)
      return Boolean;

   function Device_Supports_Swapchain
     (Device  : Vk.Physical_Device_T;
      Checked : out Natural)
      return Selection_Logic.Capability_Query_Result is
     (Selection_Logic.Swapchain_Support (Device, Checked));

   procedure Select_Physical_Device
     (Context : VC.Context;
      Choice  : out Selection;
      Status  : out Select_Status)
   is
   begin
      Selection_Logic.Select_Physical_Device (Context, Choice, Status);
   end Select_Physical_Device;

   function Is_Selected (Choice : Selection) return Boolean is
     (Selection_Logic.Is_Selected (Choice));

   function Physical_Device (Choice : Selection) return Vk.Physical_Device_T is
     (Selection_Logic.Physical_Device (Choice));

   function Queue_Family_Index (Choice : Selection) return Natural is
     (Selection_Logic.Queue_Family_Index (Choice));

   function Present_Queue_Family_Index (Choice : Selection) return Natural is
     (Selection_Logic.Present_Queue_Family_Index (Choice));

   function Diagnostics (Choice : Selection) return Diagnostic_Snapshot is
     (Selection_Logic.Diagnostics (Choice));

   procedure Create_Logical_Device
     (Choice : Selection;
      Surface : Vk.Surface_KHR_T;
      Desired_Width : Natural;
      Desired_Height : Natural;
      Device : in out Logical_Device;
      Status : out Create_Status)
   is separate;

   overriding procedure Finalize (Device : in out Logical_Device) is separate;

   function Has_Memory_Type
     (Properties : Vk.Physical_Device_Memory_Properties_T;
      Bits       : Interfaces.Unsigned_32;
      Flags      : Vk.Memory_Property_Flags_T;
      Index      : out Interfaces.Unsigned_32)
      return Boolean
   is
      Mask : Interfaces.Unsigned_32 := 1;
   begin
      Index := 0;
      if Properties.memory_Type_Count = 0 then
         return False;
      end if;

      for I in 0 .. Natural (Properties.memory_Type_Count) - 1 loop
         if (Bits and Mask) /= 0
           and then
             (Properties.memory_Types (I).property_Flags and Flags) = Flags
         then
            Index := Interfaces.Unsigned_32 (I);
            return True;
         end if;
         Mask := Interfaces.Shift_Left (Mask, 1);
      end loop;

      return False;
   end Has_Memory_Type;

   procedure Destroy_Vertex_Buffer (Device : in out Logical_Device)
     renames Resource_Lifecycle.Destroy_Vertex_Buffer;
   procedure Destroy_Atlas_Image (Device : in out Logical_Device)
     renames Resource_Lifecycle.Destroy_Atlas_Image;
   procedure Destroy_Colour_Sheet (Device : in out Logical_Device)
     renames Resource_Lifecycle.Destroy_Colour_Sheet;
   procedure Destroy_Image_Texture (Device : in out Logical_Device)
     renames Resource_Lifecycle.Destroy_Image_Texture;
   procedure Destroy_Readback_Buffer
     (Device : in out Logical_Device; Success : out Boolean)
     renames Resource_Lifecycle.Destroy_Readback_Buffer;
   procedure Destroy_Deferred_Upload
     (Device : in out Logical_Device; Success : out Boolean)
     renames Resource_Lifecycle.Destroy_Deferred_Upload;
   procedure Defer_Upload_Resources
     (Device         : in out Logical_Device;
      Staging_Buffer : in out Vk.Buffer_T;
      Staging_Memory : in out Vk.Device_Memory_T;
      Image          : in out Vk.Image_T;
      Image_Memory   : in out Vk.Device_Memory_T;
      Image_View     : in out Vk.Image_View_T)
     renames Resource_Lifecycle.Defer_Upload_Resources;
   procedure Reap_Deferred_Upload
     (Device : in out Logical_Device;
      Ready  : out Boolean;
      Status : out Create_Status)
     renames Resource_Lifecycle.Reap_Deferred_Upload;
   procedure Restore_Upload_Fence
     (Device : in out Logical_Device;
      Status : out Create_Status)
     renames Resource_Lifecycle.Restore_Upload_Fence;

   procedure Upload_Atlas_Data
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Bytes_Natural : Natural;
      Pixels        : System.Address;
      Dirty         : Boolean;
      Status        : out Create_Status)
   is separate;

   procedure Upload_Atlas
     (Device : in out Logical_Device;
      Choice : Selection;
      Batch  : VS.Submission_Batch;
      Status : out Create_Status)
   is
      procedure Upload_Pixels (Pixels : System.Address) is
      begin
         Upload_Atlas_Data
           (Device        => Device,
            Choice        => Choice,
            Width         => VS.Atlas_Width (Batch),
            Height        => VS.Atlas_Height (Batch),
            Bytes_Natural => VS.Atlas_Bytes (Batch),
            Pixels        => Pixels,
            Dirty         => VS.Atlas_Dirty (Batch),
            Status        => Status);
      end Upload_Pixels;
   begin
      if not VS.Has_Atlas_Pixels (Batch) then
         Status := Atlas_Too_Large;
         return;
      end if;
      VS.Visit_Atlas_Pixels (Batch, Upload_Pixels'Access);
   end Upload_Atlas;

   procedure Upload_Image_Texture_Staging_Source
     (Device        : in out Logical_Device;
      Slot          : Texture_Slot;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Source_Bytes_Per_Pixel : Natural;
      Row_Stride_Bytes : Natural;
      Bytes_Natural : Natural;
      Fill_Staging  : not null access procedure
        (Target   : Image_Texture_Byte_Mapping.Object_Pointer;
         Capacity : Positive;
         Status : out Create_Status);
      Status        : out Create_Status;
      Image_Format  : Vk.Format_T := Format_R8G8B8A8_Unorm;
      Maximum_Bytes : Positive := Max_Image_Texture_Bytes;
      Content_Signature : Interfaces.Unsigned_64 := 0) is separate;

   procedure Upload_Image_Texture_Row_Source
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Source_Bytes_Per_Pixel : Natural;
      Row_Stride_Bytes : Natural;
      Bytes_Natural : Natural;
      Source_Byte   : not null access function
        (Row         : Natural;
         Byte_Offset : Natural) return Interfaces.Unsigned_8;
      Status        : out Create_Status;
      Slot          : Texture_Slot := Inline_Picture)
   is
      Target_Row_Bytes : constant Natural :=
        (if Width <= Max_Image_Texture_Bytes / 4 then Width * 4 else 0);
      Source_Row_Bytes : constant Natural :=
        (if Source_Bytes_Per_Pixel > 0
           and then Width <= Max_Image_Texture_Bytes / Source_Bytes_Per_Pixel
         then Width * Source_Bytes_Per_Pixel
         else 0);
      Use_Vulkan_Row_Length : constant Boolean :=
        Source_Bytes_Per_Pixel = 4
        and then Target_Row_Bytes > 0
        and then Row_Stride_Bytes > Target_Row_Bytes
        and then Row_Stride_Bytes mod 4 = 0;

      procedure Fill_Row_Source_Staging
        (Target   : Image_Texture_Byte_Mapping.Object_Pointer;
         Capacity : Positive;
         Status : out Create_Status)
      is
         Target_Index : Natural := 1;
      begin
         Status := Ok;
         if Target = null
           or else Capacity = 0
           or else Target_Row_Bytes = 0
           or else Source_Row_Bytes = 0
         then
            Status := Atlas_Too_Large;
            return;
         end if;

         if Source_Bytes_Per_Pixel = 4
           and then Row_Stride_Bytes = Target_Row_Bytes
         then
            for Row in 0 .. Height - 1 loop
               for Offset in 0 .. Target_Row_Bytes - 1 loop
                  Target.all (Target_Index) := Source_Byte (Row, Offset);
                  Target_Index := Target_Index + 1;
               end loop;
            end loop;
         elsif Use_Vulkan_Row_Length then
            for Row in 0 .. Height - 1 loop
               declare
                  Copy_Bytes : constant Natural :=
                    (if Row = Height - 1
                     then Source_Row_Bytes
                     else Row_Stride_Bytes);
               begin
                  for Offset in 0 .. Copy_Bytes - 1 loop
                     Target.all (Target_Index) := Source_Byte (Row, Offset);
                     Target_Index := Target_Index + 1;
                  end loop;
               end;
            end loop;
         elsif Source_Bytes_Per_Pixel = 4 then
            for Row in 0 .. Height - 1 loop
               for Offset in 0 .. Target_Row_Bytes - 1 loop
                  Target.all (Target_Index) := Source_Byte (Row, Offset);
                  Target_Index := Target_Index + 1;
               end loop;
            end loop;
         else
            for Row in 0 .. Height - 1 loop
               for Pixel in 0 .. Width - 1 loop
                  declare
                     Source_Offset : constant Natural := Pixel * 3;
                  begin
                     Target.all (Target_Index) :=
                       Source_Byte (Row, Source_Offset);
                     Target.all (Target_Index + 1) :=
                       Source_Byte (Row, Source_Offset + 1);
                     Target.all (Target_Index + 2) :=
                       Source_Byte (Row, Source_Offset + 2);
                     Target.all (Target_Index + 3) := 16#FF#;
                     Target_Index := Target_Index + 4;
                  end;
               end loop;
            end loop;
         end if;
      end Fill_Row_Source_Staging;
   begin
      Upload_Image_Texture_Staging_Source
        (Slot          => Slot,
         Device        => Device,
         Choice        => Choice,
         Width         => Width,
         Height        => Height,
         Source_Bytes_Per_Pixel => Source_Bytes_Per_Pixel,
         Row_Stride_Bytes => Row_Stride_Bytes,
         Bytes_Natural => Bytes_Natural,
         Fill_Staging  => Fill_Row_Source_Staging'Access,
         Status        => Status);
   end Upload_Image_Texture_Row_Source;

   procedure Upload_Image_Texture_Encoded_Source
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Image_Source  : RM.Image_Command;
      Status        : out Create_Status)
   is
      Width : constant Natural := Image_Source.Pixel_Width;
      Height : constant Natural := Image_Source.Pixel_Height;
      Bytes_Per_Pixel : constant Natural :=
        (if Image_Source.Raw_Format = 24 then 3
         elsif Image_Source.Raw_Format = 32 then 4
         else 0);
      Row_Stride_Bytes : constant Natural :=
        Image_Source.Decoded_Row_Stride_Bytes;
      Bytes_Natural : constant Natural :=
        RM.Image_Decoded_Source_Bytes (Image_Source);

      procedure Fill_Encoded_Staging
        (Target   : Image_Texture_Byte_Mapping.Object_Pointer;
         Capacity : Positive;
         Status : out Create_Status)
      is
         Decode_Status : Terminal.App.Image_Staging.Decode_Status;

         procedure Write_Byte
           (Index    : Positive;
            Value    : Interfaces.Unsigned_8;
            Continue : in out Boolean)
         is
         begin
            if Target = null or else Index > Capacity then
               Continue := False;
            else
               Target.all (Index) := Value;
            end if;
         end Write_Byte;
      begin
         if Target = null then
            Status := Atlas_Too_Large;
            return;
         end if;
         Terminal.App.Image_Staging.Decode_Encoded_RGBA
           (Source        => Image_Source,
            Maximum_Bytes => Capacity,
            Write         => Write_Byte'Access,
            Status        => Decode_Status);
         case Decode_Status is
            when Terminal.App.Image_Staging.Decode_Ok =>
               Status := Ok;
            when Terminal.App.Image_Staging.Invalid_Source =>
               Status := Image_Staging_Invalid_Source;
            when Terminal.App.Image_Staging.Allocation_Failed =>
               Status := Image_Staging_Allocation_Failed;
         end case;
      end Fill_Encoded_Staging;
   begin
      Upload_Image_Texture_Staging_Source
        (Slot          => Inline_Picture,
         Device        => Device,
         Choice        => Choice,
         Width         => Width,
         Height        => Height,
         Source_Bytes_Per_Pixel => Bytes_Per_Pixel,
         Row_Stride_Bytes => Row_Stride_Bytes,
         Bytes_Natural => Bytes_Natural,
         Fill_Staging  => Fill_Encoded_Staging'Access,
         Status        => Status);
   end Upload_Image_Texture_Encoded_Source;

   --  All inline pictures share one descriptor binding. Pack every distinct
   --  source used by this submission into a single RGBA atlas so that quads do
   --  not all sample the final image uploaded for the frame.
   procedure Upload_Image_Atlas
     (Device : in out Logical_Device;
      Choice : Selection;
      Batch  : VS.Submission_Batch;
      Status : out Create_Status)
   is separate;

   procedure Upload_Image_Texture_Rows
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Source_Bytes_Per_Pixel : Natural;
      Row_Stride_Bytes : Natural;
      Bytes_Natural : Natural;
      Pixels        : System.Address;
      Status        : out Create_Status;
      Slot          : Texture_Slot := Inline_Picture)
   is
      Source : constant Image_Texture_Byte_Mapping.Object_Pointer :=
        Image_Texture_Byte_Mapping.To_Pointer (Pixels);

      function Flat_Source_Byte
        (Row         : Natural;
         Byte_Offset : Natural) return Interfaces.Unsigned_8
      is
      begin
         return Source.all (Row * Row_Stride_Bytes + Byte_Offset + 1);
      end Flat_Source_Byte;
   begin
      if Pixels = System.Null_Address then
         Status := Atlas_Too_Large;
         return;
      end if;

      Upload_Image_Texture_Row_Source
        (Device        => Device,
         Choice        => Choice,
         Width         => Width,
         Height        => Height,
         Source_Bytes_Per_Pixel => Source_Bytes_Per_Pixel,
         Row_Stride_Bytes => Row_Stride_Bytes,
         Bytes_Natural => Bytes_Natural,
         Source_Byte   => Flat_Source_Byte'Access,
         Status        => Status,
         Slot          => Slot);
   end Upload_Image_Texture_Rows;

   procedure Upload_Image_Texture_Data
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Bytes_Natural : Natural;
      Pixels        : System.Address;
      Status        : out Create_Status;
      Slot          : Texture_Slot := Inline_Picture)
   is
   begin
      Upload_Image_Texture_Rows
        (Slot             => Slot,
         Device           => Device,
         Choice           => Choice,
         Width            => Width,
         Height           => Height,
         Source_Bytes_Per_Pixel => 4,
         Row_Stride_Bytes =>
           (if Width <= Max_Image_Texture_Bytes / 4 then Width * 4 else 0),
         Bytes_Natural    => Bytes_Natural,
         Pixels           => Pixels,
         Status           => Status);
   end Upload_Image_Texture_Data;

   procedure Ensure_Vertex_Buffer
     (Device : in out Logical_Device;
      Choice : Selection;
      Bytes  : Interfaces.Unsigned_64;
      Status : out Create_Status)
   is
      Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         size                     => Bytes,
         usage                    => Vk.BUFFER_USAGE_VERTEX_BUFFER_BIT,
         sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices   => System.Null_Address);
      Buffer : aliased Vk.Buffer_T := System.Null_Address;
      Requirements : aliased Vk.Memory_Requirements_T;
      Memory_Properties : aliased Vk.Physical_Device_Memory_Properties_T;
      Memory_Type_Index : Interfaces.Unsigned_32 := 0;
      Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
      Memory : aliased Vk.Device_Memory_T := System.Null_Address;
      Result : Vk.Result_T;

      procedure Destroy_Buffer_Call (Handle : Vk.Buffer_T) is
      begin
         Vk.Destroy_Buffer (Device.Device, Handle, System.Null_Address);
      end Destroy_Buffer_Call;

      procedure Free_Memory_Call (Handle : Vk.Device_Memory_T) is
      begin
         Vk.Free_Memory (Device.Device, Handle, System.Null_Address);
      end Free_Memory_Call;

      procedure Destroy_Local_Chain is new Terminal.App.Vulkan_Destroy_Pair
        (Vk.Buffer_T, System.Null_Address,
         "destroy uncommitted Vulkan vertex buffer", Destroy_Buffer_Call,
         Vk.Device_Memory_T, System.Null_Address,
         "free uncommitted Vulkan vertex memory", Free_Memory_Call);

      procedure Cleanup_Local is
         Cleanup_Ok : Boolean;
      begin
         Destroy_Local_Chain (Buffer, Memory, Cleanup_Ok);
         if not Cleanup_Ok then
            Device.Cleanup_Quarantined := True;
            Status := Device_Lost;
         end if;
      end Cleanup_Local;
   begin
      if Device.Vertex_Buffer /= System.Null_Address
        and then Device.Vertex_Buffer_Bytes >= Natural (Bytes)
      then
         Status := Ok;
         return;
      end if;

      Destroy_Vertex_Buffer (Device);

      Result :=
        Vk.Create_Buffer
          (Device.Device, Buffer_Info'Address, System.Null_Address, Buffer'Address);
      if Result /= Vk.SUCCESS or else Buffer = System.Null_Address then
         Status := Create_Vertex_Buffer_Failed;
         Cleanup_Local;
         return;
      end if;

      Vk.Get_Buffer_Memory_Requirements
        (Device.Device, Buffer, Requirements'Address);
      Vk.Get_Physical_Device_Memory_Properties
        (Choice.Physical_Device, Memory_Properties'Address);

      if not Has_Memory_Type
        (Memory_Properties,
         Requirements.memory_Type_Bits,
         Vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT or
           Vk.MEMORY_PROPERTY_HOST_COHERENT_BIT,
         Memory_Type_Index)
      then
         Status := Allocate_Vertex_Memory_Failed;
         Cleanup_Local;
         return;
      end if;

      Allocate_Info :=
        (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
         p_Next            => System.Null_Address,
         allocation_Size   => Requirements.size,
         memory_Type_Index => Memory_Type_Index);

      Result :=
        Vk.Allocate_Memory
          (Device.Device, Allocate_Info'Address, System.Null_Address, Memory'Address);
      if Result /= Vk.SUCCESS or else Memory = System.Null_Address then
         Status := Allocate_Vertex_Memory_Failed;
         Cleanup_Local;
         return;
      end if;

      Result := Vk.Bind_Buffer_Memory (Device.Device, Buffer, Memory, 0);
      if Result /= Vk.SUCCESS then
         Status := Bind_Vertex_Buffer_Failed;
         Cleanup_Local;
         return;
      end if;

      Device.Vertex_Buffer := Buffer;
      Device.Vertex_Memory := Memory;
      Buffer := System.Null_Address;
      Memory := System.Null_Address;
      Device.Vertex_Buffer_Bytes := Natural (Bytes);
      Status := Ok;
   exception
      when others =>
         Cleanup_Local;
         raise;
   end Ensure_Vertex_Buffer;

   procedure Check_Frame_Resources
     (Device    : in out Logical_Device;
      Available : out Boolean;
      Status    : out Create_Status)
   is
      Result : Vk.Result_T;
   begin
      Available := False;
      Status := Ok;
      for I in 1 .. Device.Sync_Frame_Count loop
         if Device.In_Flight (I) /= System.Null_Address then
            Result := Vk.Get_Fence_Status (Device.Device, Device.In_Flight (I));
            if Result = Vk.NOT_READY then
               if Device.Fence_Deferred_Upload_Count < Natural'Last then
                  Device.Fence_Deferred_Upload_Count :=
                    Device.Fence_Deferred_Upload_Count + 1;
               end if;
               Status := Resources_In_Flight;
               return;
            elsif Result /= Vk.SUCCESS then
               Status :=
                 (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
                  else Create_Device_Failed);
               return;
            end if;
         end if;
      end loop;
      Available := True;
   end Check_Frame_Resources;

   procedure Upload
     (Device : in out Logical_Device;
      Choice : Selection;
      Batch  : VS.Submission_Batch;
      Status : out Create_Status)
   is separate;

   procedure Enable_Framebuffer_Readback
     (Device : in out Logical_Device;
      Choice : Selection;
      Status : out Readback_Status)
   is separate;

   procedure Readback_Pixel
     (Device : in out Logical_Device;
      X, Y   : Natural;
      Red, Green, Blue, Alpha : out Terminal.Common.Bytes.Byte;
      Status : out Readback_Status)
   is separate;

   procedure Render
     (Device : in out Logical_Device;
      Status : out Render_Status)
   is separate;

   function Is_Initialized (Device : Logical_Device) return Boolean is
     (Device.Initialized);

   function Device_Handle (Device : Logical_Device) return Vk.Device_T is
     (Device.Device);

   function Graphics_Queue (Device : Logical_Device) return Vk.Queue_T is
     (Device.Queue);

   function Queue_Family_Index (Device : Logical_Device) return Natural is
     (Device.Queue_Family_Index);

   function Diagnostics
     (Device                : Logical_Device;
      Include_Image_Preview : Boolean := True)
      return Device_Diagnostic_Snapshot is
     (Snapshots.Capture (Device, Include_Image_Preview));

end Terminal.App.Vulkan_Device;
