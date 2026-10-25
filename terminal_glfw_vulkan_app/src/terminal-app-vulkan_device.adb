with Interfaces;
with Ada.Unchecked_Deallocation;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with System.Address_To_Access_Conversions;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.App.Image_Staging;
with Terminal.App.Image_Upload_Layout;
with Terminal.App.Shaders;
with Terminal.App.Status_Labels;
with Terminal.App.Vulkan_Retirement;

package body Terminal.App.Vulkan_Device is
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
   use type RM.Image_Data_Access;
   use type RM.Image_Decoded_Source_Kind;
   use type Terminal.App.Image_Staging.Decode_Status;
   use type Terminal.App.Image_Upload_Layout.Layout_Status;

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Humanize (Text : String) return String
      renames Terminal.App.Status_Labels.Humanize;

   function Bounded (Text : String) return String is
   begin
      return Terminal.App.Status_Labels.Bounded
        (Text, Max_Status_Label_Length);
   end Bounded;

   function Select_Status_Label (Status : Select_Status) return String is
   begin
      return Bounded ("Select device: " & Humanize (Select_Status'Image (Status)));
   end Select_Status_Label;

   function Create_Status_Label (Status : Create_Status) return String is
   begin
      return Bounded ("Create device: " & Humanize (Create_Status'Image (Status)));
   end Create_Status_Label;

   function Render_Status_Label (Status : Render_Status) return String is
   begin
      return Bounded ("Render device: " & Humanize (Render_Status'Image (Status)));
   end Render_Status_Label;

   package VC renames Terminal.App.Vulkan_Context;
   package Shaders renames Terminal.App.Shaders;
   package VS renames Terminal.App.Vulkan_Submit;

   use type Shaders.Load_Status;
   use type VS.Vertex_Array_Access;
   use type VS.Texture_Source;

   subtype Device_Count_Range is Positive range 1 .. Max_Physical_Devices;
   subtype Queue_Count_Range is Positive range 1 .. Max_Queue_Families;
   subtype Extension_Count_Range is Positive range 1 .. Max_Device_Extensions;
   subtype Surface_Format_Count_Range is Positive range 1 .. Max_Surface_Formats;
   subtype Present_Mode_Count_Range is Positive range 1 .. Max_Present_Modes;
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

   type Physical_Device_Array is array (Device_Count_Range) of Vk.Physical_Device_T
     with Convention => C;
   type Queue_Family_Array is array (Queue_Count_Range) of Vk.Queue_Family_Properties_T
     with Convention => C;
   type Extension_Array is array (Extension_Count_Range) of Vk.Extension_Properties_T
     with Convention => C;
   type Surface_Format_Array is
     array (Surface_Format_Count_Range) of Vk.Surface_Format_KHR_T
     with Convention => C;
   type Present_Mode_Array is
     array (Present_Mode_Count_Range) of Vk.Present_Mode_KHR_T
     with Convention => C;
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

   function Sample_Count_Value
     (Samples : Vk.Sample_Count_Flag_Bits_T)
      return Natural
   is
   begin
      if Samples = Vk.SAMPLE_COUNT_64_BIT then
         return 64;
      elsif Samples = Vk.SAMPLE_COUNT_32_BIT then
         return 32;
      elsif Samples = Vk.SAMPLE_COUNT_16_BIT then
         return 16;
      elsif Samples = Vk.SAMPLE_COUNT_8_BIT then
         return 8;
      elsif Samples = Vk.SAMPLE_COUNT_4_BIT then
         return 4;
      elsif Samples = Vk.SAMPLE_COUNT_2_BIT then
         return 2;
      else
         return 1;
      end if;
   end Sample_Count_Value;

   function Is_Swapchain_Stale (Result : Vk.Result_T) return Boolean is
     (Result = Suboptimal_KHR or else Result = Error_Out_Of_Date_KHR);

   procedure Destroy_Atlas_Image (Device : in out Logical_Device);
   procedure Destroy_Image_Texture (Device : in out Logical_Device);
   procedure Destroy_Colour_Sheet (Device : in out Logical_Device);
   procedure Destroy_Deferred_Upload
     (Device  : in out Logical_Device;
      Success : out Boolean);

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

   procedure Restore_Upload_Fence (Device : in out Logical_Device);

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

   procedure Reset
     (Choice : out Selection;
      Status : Select_Status) is
   begin
      Choice :=
        (Selected               => False,
         Physical_Device        => System.Null_Address,
         Queue_Family_Index     => 0,
         Physical_Device_Count  => 0,
         Devices_Inspected      => 0,
         Queue_Families_Checked => 0,
         Surface_Format_Count   => 0,
         Present_Mode_Count     => 0,
         Device_Extensions_Checked => 0,
         Swapchain_Extension_Found => False,
         Last_Status            => Status);
   end Reset;

   function Has_Memory_Type
     (Properties : Vk.Physical_Device_Memory_Properties_T;
      Bits       : Interfaces.Unsigned_32;
      Flags      : Vk.Memory_Property_Flags_T;
      Index      : out Interfaces.Unsigned_32)
      return Boolean;

   function Has_Name
     (Item : Vk.Extension_Properties_T;
      Name : String)
      return Boolean is
   begin
      for I in Name'Range loop
         if Item.extension_Name (I - Name'First) /=
           Interfaces.C.char'Val (Character'Pos (Name (I)))
         then
            return False;
         end if;
      end loop;

      return Item.extension_Name (Name'Length) = Interfaces.C.nul;
   end Has_Name;

   function Device_Supports_Swapchain
     (Device  : Vk.Physical_Device_T;
      Checked : out Natural)
      return Boolean
   is
      Count : aliased Interfaces.Unsigned_32 := 0;
      Limit : Interfaces.Unsigned_32;
      Extensions : Extension_Array;
      Result : Vk.Result_T;

   begin
      Checked := 0;

      Result :=
        Vk.Enumerate_Device_Extension_Properties
          (Device, System.Null_Address, Count'Address, System.Null_Address);
      if Result /= Vk.SUCCESS or else Count = 0 then
         return False;
      end if;

      Limit := U32_Min (Count, Interfaces.Unsigned_32 (Max_Device_Extensions));
      Count := Limit;
      Result :=
        Vk.Enumerate_Device_Extension_Properties
          (Device, System.Null_Address, Count'Address, Extensions'Address);
      if Result /= Vk.SUCCESS then
         return False;
      end if;

      Checked := Natural (Count);
      for I in 1 .. Natural (Count) loop
         if Has_Name (Extensions (I), "VK_KHR_swapchain") then
            return True;
         end if;
      end loop;

      return False;
   end Device_Supports_Swapchain;

   function Surface_Detail_Counts_Are_Usable
     (Device       : Vk.Physical_Device_T;
      Surface      : Vk.Surface_KHR_T;
      Format_Count : out Natural;
      Mode_Count   : out Natural)
      return Boolean
   is
      Formats : aliased Interfaces.Unsigned_32 := 0;
      Modes   : aliased Interfaces.Unsigned_32 := 0;
      Result  : Vk.Result_T;
   begin
      Format_Count := 0;
      Mode_Count := 0;

      Result :=
        Vk.Get_Physical_Device_Surface_Formats_KHR
          (Device, Surface, Formats'Address, System.Null_Address);
      if Result /= Vk.SUCCESS then
         return False;
      end if;

      Result :=
        Vk.Get_Physical_Device_Surface_Present_Modes_KHR
          (Device, Surface, Modes'Address, System.Null_Address);
      if Result /= Vk.SUCCESS then
         return False;
      end if;

      Format_Count := Natural (Formats);
      Mode_Count := Natural (Modes);
      return Formats > 0 and then Modes > 0;
   end Surface_Detail_Counts_Are_Usable;

   function Queue_Supports_Graphics_And_Present
     (Device      : Vk.Physical_Device_T;
      Surface     : Vk.Surface_KHR_T;
      Queue_Index : Interfaces.Unsigned_32;
      Props       : Vk.Queue_Family_Properties_T)
      return Boolean
   is
      Supported : aliased Interfaces.Unsigned_32 := 0;
      Result    : constant Vk.Result_T :=
        Vk.Get_Physical_Device_Surface_Support_KHR
          (Device, Queue_Index, Surface, Supported'Address);
   begin
      if Result /= Vk.SUCCESS then
         return False;
      end if;

      return Props.queue_Count > 0
        and then (Props.queue_Flags and Vk.QUEUE_GRAPHICS_BIT) /= 0
        and then Supported /= 0;
   end Queue_Supports_Graphics_And_Present;

   procedure Select_Physical_Device
     (Context : VC.Context;
      Choice  : out Selection;
      Status  : out Select_Status)
   is
      Count : aliased Interfaces.Unsigned_32 := 0;
      Result : Vk.Result_T;
      Devices : Physical_Device_Array := (others => System.Null_Address);
      Device_Limit : Interfaces.Unsigned_32;
      Surface : constant Vk.Surface_KHR_T := VC.Surface (Context);
      Query_Failed : Boolean := False;
   begin
      Reset (Choice, Context_Not_Initialized);

      if not VC.Is_Initialized (Context) or else Surface = System.Null_Address then
         Status := Context_Not_Initialized;
         Choice.Last_Status := Status;
         return;
      end if;

      Result :=
        Vk.Enumerate_Physical_Devices
          (VC.Instance (Context), Count'Address, System.Null_Address);
      if Result /= Vk.SUCCESS then
         Status := Surface_Query_Failed;
         Choice.Last_Status := Status;
         return;
      end if;

      Choice.Physical_Device_Count := Natural (Count);
      if Count = 0 then
         Status := No_Physical_Devices;
         Choice.Last_Status := Status;
         return;
      end if;

      Device_Limit := U32_Min (Count, Interfaces.Unsigned_32 (Max_Physical_Devices));
      Count := Device_Limit;

      Result :=
        Vk.Enumerate_Physical_Devices
          (VC.Instance (Context), Count'Address, Devices'Address);
      if Result /= Vk.SUCCESS then
         Status := Surface_Query_Failed;
         Choice.Last_Status := Status;
         return;
      end if;

      for D in 1 .. Natural (Count) loop
         declare
            Queue_Count : aliased Interfaces.Unsigned_32 := 0;
            Queue_Limit : Interfaces.Unsigned_32;
            Queues : Queue_Family_Array;
            Format_Count : Natural := 0;
            Mode_Count : Natural := 0;
            Extension_Count : Natural := 0;
         begin
            Choice.Devices_Inspected := Choice.Devices_Inspected + 1;

            if not Device_Supports_Swapchain (Devices (D), Extension_Count) then
               Choice.Device_Extensions_Checked :=
                 Choice.Device_Extensions_Checked + Extension_Count;
            elsif not Surface_Detail_Counts_Are_Usable
              (Devices (D), Surface, Format_Count, Mode_Count)
            then
               Choice.Device_Extensions_Checked :=
                 Choice.Device_Extensions_Checked + Extension_Count;
               Choice.Swapchain_Extension_Found := True;
               Query_Failed := True;
            else
               Choice.Device_Extensions_Checked :=
                 Choice.Device_Extensions_Checked + Extension_Count;
               Choice.Swapchain_Extension_Found := True;
               Vk.Get_Physical_Device_Queue_Family_Properties
                 (Devices (D), Queue_Count'Address, System.Null_Address);

               if Queue_Count > 0 then
                  Queue_Limit :=
                    U32_Min (Queue_Count, Interfaces.Unsigned_32 (Max_Queue_Families));
                  Queue_Count := Queue_Limit;
                  Vk.Get_Physical_Device_Queue_Family_Properties
                    (Devices (D), Queue_Count'Address, Queues'Address);

                  for Q in 1 .. Natural (Queue_Count) loop
                     Choice.Queue_Families_Checked :=
                       Choice.Queue_Families_Checked + 1;
                     if Queue_Supports_Graphics_And_Present
                       (Devices (D),
                        Surface,
                        Interfaces.Unsigned_32 (Q - 1),
                        Queues (Q))
                     then
                        Choice.Selected := True;
                        Choice.Physical_Device := Devices (D);
                        Choice.Queue_Family_Index := Q - 1;
                        Choice.Surface_Format_Count := Format_Count;
                        Choice.Present_Mode_Count := Mode_Count;
                        Choice.Last_Status := Ok;
                        Status := Ok;
                        return;
                     end if;
                  end loop;
               end if;
            end if;
         end;
      end loop;

      if Query_Failed then
         Status := Surface_Query_Failed;
      else
         Status := No_Suitable_Device;
      end if;
      Choice.Last_Status := Status;
   end Select_Physical_Device;

   function Is_Selected (Choice : Selection) return Boolean is
     (Choice.Selected);

   function Physical_Device (Choice : Selection) return Vk.Physical_Device_T is
     (Choice.Physical_Device);

   function Queue_Family_Index (Choice : Selection) return Natural is
     (Choice.Queue_Family_Index);

   function Diagnostics (Choice : Selection) return Diagnostic_Snapshot is
   begin
      return
        (Selected               => Choice.Selected,
         Physical_Device_Count  => Choice.Physical_Device_Count,
         Devices_Inspected      => Choice.Devices_Inspected,
         Queue_Families_Checked => Choice.Queue_Families_Checked,
         Queue_Family_Index     => Choice.Queue_Family_Index,
         Surface_Format_Count   => Choice.Surface_Format_Count,
         Present_Mode_Count     => Choice.Present_Mode_Count,
         Device_Extensions_Checked => Choice.Device_Extensions_Checked,
         Swapchain_Extension_Found => Choice.Swapchain_Extension_Found,
         Last_Status            => Choice.Last_Status);
   end Diagnostics;

   procedure Create_Logical_Device
     (Choice : Selection;
      Surface : Vk.Surface_KHR_T;
      Desired_Width : Natural;
      Desired_Height : Natural;
      Device : out Logical_Device;
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

   procedure Destroy_Vertex_Buffer (Device : in out Logical_Device) is
   begin
      if Device.Vertex_Buffer /= System.Null_Address then
         Vk.Destroy_Buffer
           (Device.Device, Device.Vertex_Buffer, System.Null_Address);
         Device.Vertex_Buffer := System.Null_Address;
      end if;

      if Device.Vertex_Memory /= System.Null_Address then
         Vk.Free_Memory
           (Device.Device, Device.Vertex_Memory, System.Null_Address);
         Device.Vertex_Memory := System.Null_Address;
      end if;

      Device.Vertex_Buffer_Bytes := 0;
      Device.Uploaded_Vertex_Count := 0;
      Device.Uploaded_Text_Run_Count := 0;
      Device.Uploaded_Shaped_Glyph_Count := 0;
   end Destroy_Vertex_Buffer;

   procedure Destroy_Atlas_Image (Device : in out Logical_Device) is
   begin
      if Device.Atlas_View /= System.Null_Address then
         Vk.Destroy_Image_View
           (Device.Device, Device.Atlas_View, System.Null_Address);
         Device.Atlas_View := System.Null_Address;
      end if;

      if Device.Atlas_Image /= System.Null_Address then
         Vk.Destroy_Image
           (Device.Device, Device.Atlas_Image, System.Null_Address);
         Device.Atlas_Image := System.Null_Address;
      end if;

      if Device.Atlas_Memory /= System.Null_Address then
         Vk.Free_Memory
           (Device.Device, Device.Atlas_Memory, System.Null_Address);
         Device.Atlas_Memory := System.Null_Address;
      end if;

      Device.Atlas_Width := 0;
      Device.Atlas_Height := 0;
      Device.Atlas_Bytes := 0;
   end Destroy_Atlas_Image;

   procedure Destroy_Colour_Sheet (Device : in out Logical_Device) is
   begin
      if Device.Colour_Sheet_View /= System.Null_Address then
         Vk.Destroy_Image_View
           (Device.Device, Device.Colour_Sheet_View, System.Null_Address);
         Device.Colour_Sheet_View := System.Null_Address;
      end if;

      if Device.Colour_Sheet_Image /= System.Null_Address then
         Vk.Destroy_Image
           (Device.Device, Device.Colour_Sheet_Image, System.Null_Address);
         Device.Colour_Sheet_Image := System.Null_Address;
      end if;

      if Device.Colour_Sheet_Memory /= System.Null_Address then
         Vk.Free_Memory
           (Device.Device, Device.Colour_Sheet_Memory, System.Null_Address);
         Device.Colour_Sheet_Memory := System.Null_Address;
      end if;

      Device.Colour_Sheet_Width := 0;
      Device.Colour_Sheet_Height := 0;
   end Destroy_Colour_Sheet;

   procedure Destroy_Image_Texture (Device : in out Logical_Device) is
   begin
      if Device.Image_Texture_View /= System.Null_Address then
         Vk.Destroy_Image_View
           (Device.Device, Device.Image_Texture_View, System.Null_Address);
         Device.Image_Texture_View := System.Null_Address;
      end if;

      if Device.Image_Texture_Image /= System.Null_Address then
         Vk.Destroy_Image
           (Device.Device, Device.Image_Texture_Image, System.Null_Address);
         Device.Image_Texture_Image := System.Null_Address;
      end if;

      if Device.Image_Texture_Memory /= System.Null_Address then
         Vk.Free_Memory
           (Device.Device, Device.Image_Texture_Memory, System.Null_Address);
         Device.Image_Texture_Memory := System.Null_Address;
      end if;

      Device.Image_Texture_Width := 0;
      Device.Image_Texture_Height := 0;
      Device.Image_Texture_Bytes := 0;
      Device.Image_Texture_Content_Signature := 0;
      if Device.Image_Texture_Descriptor_Bound_Count > 1 then
         Device.Image_Texture_Descriptor_Bound_Count := 1;
      end if;
   end Destroy_Image_Texture;

   procedure Destroy_Deferred_Upload
     (Device  : in out Logical_Device;
      Success : out Boolean)
   is
      procedure Note_Failure is
      begin
         Success := False;
      end Note_Failure;
   begin
      Success := True;
      if Device.Deferred_Upload_View /= System.Null_Address then
         begin
            Vk.Destroy_Image_View
              (Device.Device,
               Device.Deferred_Upload_View,
               System.Null_Address);
         exception
            when others => Note_Failure;
         end;
      end if;
      Device.Deferred_Upload_View := System.Null_Address;
      if Device.Deferred_Upload_Image /= System.Null_Address then
         begin
            Vk.Destroy_Image
              (Device.Device,
               Device.Deferred_Upload_Image,
               System.Null_Address);
         exception
            when others => Note_Failure;
         end;
      end if;
      Device.Deferred_Upload_Image := System.Null_Address;
      if Device.Deferred_Upload_Image_Memory /= System.Null_Address then
         begin
            Vk.Free_Memory
              (Device.Device,
               Device.Deferred_Upload_Image_Memory,
               System.Null_Address);
         exception
            when others => Note_Failure;
         end;
      end if;
      Device.Deferred_Upload_Image_Memory := System.Null_Address;
      if Device.Deferred_Upload_Buffer /= System.Null_Address then
         begin
            Vk.Destroy_Buffer
              (Device.Device,
               Device.Deferred_Upload_Buffer,
               System.Null_Address);
         exception
            when others => Note_Failure;
         end;
      end if;
      Device.Deferred_Upload_Buffer := System.Null_Address;
      if Device.Deferred_Upload_Memory /= System.Null_Address then
         begin
            Vk.Free_Memory
              (Device.Device,
               Device.Deferred_Upload_Memory,
               System.Null_Address);
         exception
            when others => Note_Failure;
         end;
      end if;
      Device.Deferred_Upload_Memory := System.Null_Address;
      Device.Deferred_Upload_Pending := False;
   end Destroy_Deferred_Upload;

   procedure Defer_Upload_Resources
     (Device         : in out Logical_Device;
      Staging_Buffer : in out Vk.Buffer_T;
      Staging_Memory : in out Vk.Device_Memory_T;
      Image          : in out Vk.Image_T;
      Image_Memory   : in out Vk.Device_Memory_T;
      Image_View     : in out Vk.Image_View_T) is
   begin
      if Device.Deferred_Upload_Pending then
         raise Program_Error with "an upload retirement is already pending";
      end if;
      Device.Deferred_Upload_Buffer := Staging_Buffer;
      Device.Deferred_Upload_Memory := Staging_Memory;
      Device.Deferred_Upload_Image := Image;
      Device.Deferred_Upload_Image_Memory := Image_Memory;
      Device.Deferred_Upload_View := Image_View;
      Device.Deferred_Upload_Pending := True;
      Staging_Buffer := System.Null_Address;
      Staging_Memory := System.Null_Address;
      Image := System.Null_Address;
      Image_Memory := System.Null_Address;
      Image_View := System.Null_Address;
   end Defer_Upload_Resources;

   procedure Reap_Deferred_Upload
     (Device : in out Logical_Device;
      Ready  : out Boolean;
      Status : out Create_Status)
   is
      Result : Vk.Result_T;
      Cleanup_Succeeded : Boolean := True;
      Fence : Terminal.App.Vulkan_Retirement.Fence_Outcome;
      Outcome : Terminal.App.Vulkan_Retirement.Retirement_Outcome;
   begin
      Ready := True;
      Status := Ok;
      if not Device.Deferred_Upload_Pending then
         return;
      elsif Device.Upload_Fence = System.Null_Address then
         Ready := False;
         Status := Copy_Atlas_Failed;
         return;
      end if;
      Result := Vk.Get_Fence_Status (Device.Device, Device.Upload_Fence);
      if Result = Vk.SUCCESS then
         Fence := Terminal.App.Vulkan_Retirement.Fence_Ready;
         Destroy_Deferred_Upload (Device, Cleanup_Succeeded);
      elsif Result = Vk.ERROR_DEVICE_LOST then
         Fence := Terminal.App.Vulkan_Retirement.Fence_Device_Lost;
         Destroy_Deferred_Upload (Device, Cleanup_Succeeded);
      elsif Result = Vk.NOT_READY then
         Fence := Terminal.App.Vulkan_Retirement.Fence_In_Flight;
      else
         Fence := Terminal.App.Vulkan_Retirement.Fence_Failed;
      end if;

      Outcome := Terminal.App.Vulkan_Retirement.Evaluate
        (Fence, Cleanup_Succeeded);
      case Outcome is
         when Terminal.App.Vulkan_Retirement.Retired =>
            null;
         when Terminal.App.Vulkan_Retirement.Still_In_Flight =>
            Ready := False;
            Status := Resources_In_Flight;
         when Terminal.App.Vulkan_Retirement.Device_Lost =>
            Ready := False;
            Status := Device_Lost;
         when Terminal.App.Vulkan_Retirement.Cleanup_Failed
            | Terminal.App.Vulkan_Retirement.Fence_Failed =>
            Ready := False;
            Status := Copy_Atlas_Failed;
      end case;
   end Reap_Deferred_Upload;

   procedure Restore_Upload_Fence (Device : in out Logical_Device) is
      Fence_Info : aliased Vk.Fence_Create_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_FENCE_CREATE_INFO,
         p_Next => System.Null_Address,
         flags  => Vk.FENCE_CREATE_SIGNALED_BIT);
      Result : Vk.Result_T;
   begin
      --  Queue submission failed after the fence was reset.  Vulkan will not
      --  signal a fence which was not successfully submitted, so replace it
      --  with a signalled fence before any later upload retries.
      if Device.Upload_Fence /= System.Null_Address then
         Vk.Destroy_Fence
           (Device.Device, Device.Upload_Fence, System.Null_Address);
         Device.Upload_Fence := System.Null_Address;
      end if;

      Result :=
        Vk.Create_Fence
          (Device.Device,
           Fence_Info'Address,
           System.Null_Address,
           Device.Upload_Fence'Address);
      if Result /= Vk.SUCCESS then
         Device.Upload_Fence := System.Null_Address;
      end if;
   end Restore_Upload_Fence;

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
      Status : out Create_Status) is
   begin
      Upload_Atlas_Data
        (Device        => Device,
         Choice        => Choice,
         Width         => VS.Atlas_Width (Batch),
         Height        => VS.Atlas_Height (Batch),
         Bytes_Natural => VS.Atlas_Bytes (Batch),
         Pixels        => VS.Atlas_Pixels (Batch),
         Dirty         => VS.Atlas_Dirty (Batch),
         Status        => Status);
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
         Vk.Destroy_Buffer (Device.Device, Buffer, System.Null_Address);
         Status := Allocate_Vertex_Memory_Failed;
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
         Vk.Destroy_Buffer (Device.Device, Buffer, System.Null_Address);
         Status := Allocate_Vertex_Memory_Failed;
         return;
      end if;

      Result := Vk.Bind_Buffer_Memory (Device.Device, Buffer, Memory, 0);
      if Result /= Vk.SUCCESS then
         Vk.Free_Memory (Device.Device, Memory, System.Null_Address);
         Vk.Destroy_Buffer (Device.Device, Buffer, System.Null_Address);
         Status := Bind_Vertex_Buffer_Failed;
         return;
      end if;

      Device.Vertex_Buffer := Buffer;
      Device.Vertex_Memory := Memory;
      Device.Vertex_Buffer_Bytes := Natural (Bytes);
      Status := Ok;
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

   function Diagnostics (Device : Logical_Device)
                         return Device_Diagnostic_Snapshot is
   begin
      return
        (Initialized        => Device.Initialized,
         Queue_Family_Index => Device.Queue_Family_Index,
         Swapchain_Created  => Device.Swapchain /= System.Null_Address,
         Swapchain_Image_Count => Device.Swapchain_Image_Count,
         Swapchain_View_Count => Device.Swapchain_View_Count,
         Framebuffer_Count => Device.Framebuffer_Count,
         Render_Pass_Created => Device.Render_Pass /= System.Null_Address,
         Command_Pool_Created => Device.Command_Pool /= System.Null_Address,
         Command_Buffer_Count => Device.Command_Buffer_Count,
         Sync_Frame_Count   => Device.Sync_Frame_Count,
         Pipeline_Layout_Created => Device.Pipeline_Layout /= System.Null_Address,
         Graphics_Pipeline_Created => Device.Graphics_Pipeline /= System.Null_Address,
         Descriptor_Set_Layout_Created =>
           Device.Descriptor_Set_Layout /= System.Null_Address,
         Descriptor_Pool_Created => Device.Descriptor_Pool /= System.Null_Address,
         Descriptor_Set_Allocated => Device.Descriptor_Set /= System.Null_Address,
         Vertex_Buffer_Created => Device.Vertex_Buffer /= System.Null_Address,
         Vertex_Buffer_Bytes => Device.Vertex_Buffer_Bytes,
         Uploaded_Vertex_Count => Device.Uploaded_Vertex_Count,
         Uploaded_Image_Command_Count => Device.Uploaded_Image_Command_Count,
         Uploaded_Image_Vertex_Count => Device.Uploaded_Image_Vertex_Count,
         Uploaded_Image_Texture_Vertex_Count =>
           Device.Uploaded_Image_Texture_Vertex_Count,
         Uploaded_Image_Protocol => Device.Uploaded_Image_Protocol,
         Uploaded_Image_Width => Device.Uploaded_Image_Width,
         Uploaded_Image_Height => Device.Uploaded_Image_Height,
         Uploaded_Image_Raw_Format => Device.Uploaded_Image_Raw_Format,
         Uploaded_Image_Pixel_Width => Device.Uploaded_Image_Pixel_Width,
         Uploaded_Image_Pixel_Height => Device.Uploaded_Image_Pixel_Height,
         Uploaded_Image_Payload_Length =>
           Device.Uploaded_Image_Payload_Length,
         Uploaded_Image_Texture_Staging_Bytes =>
           Device.Uploaded_Image_Texture_Staging_Bytes,
         Uploaded_Image_Payload_Preview_Complete =>
           Device.Uploaded_Image_Payload_Preview_Complete,
         Uploaded_Image_Encoded_Preview_Length =>
           Device.Uploaded_Image_Encoded_Preview_Length,
         Uploaded_Image_Decoded_Preview_Length =>
           Device.Uploaded_Image_Decoded_Preview_Length,
         Uploaded_Image_Decoded_Preview_Bytes =>
           Device.Uploaded_Image_Decoded_Preview_Bytes,
         Uploaded_Image_Preview_Decode_Complete =>
           Device.Uploaded_Image_Preview_Decode_Complete,
         Uploaded_Image_Decode_Status => Device.Uploaded_Image_Decode_Status,
         Uploaded_Image_Placeholder => Device.Uploaded_Image_Placeholder,
         Uploaded_Image_Texture_Downgraded =>
           Device.Uploaded_Image_Texture_Downgraded,
         Uploaded_Image_Texture_Source => Device.Uploaded_Image_Texture_Source,
         Uploaded_Text_Run_Count => Device.Uploaded_Text_Run_Count,
         Uploaded_Shaped_Glyph_Count => Device.Uploaded_Shaped_Glyph_Count,
         Rendered_Frame_Count => Device.Rendered_Frame_Count,
         Color_Sample_Count => Sample_Count_Value (Device.Color_Sample_Count),
         Color_MSAA_Created => Device.Color_MSAA_View /= System.Null_Address,
         Atlas_Image_Created => Device.Atlas_Image /= System.Null_Address,
         Atlas_View_Created => Device.Atlas_View /= System.Null_Address,
         Atlas_Sampler_Created => Device.Atlas_Sampler /= System.Null_Address,
         Image_Texture_Descriptor_Capacity =>
           Device.Image_Texture_Descriptor_Capacity,
         Image_Texture_Descriptor_Bound_Count =>
           Device.Image_Texture_Descriptor_Bound_Count,
         Image_Texture_Upload_Count => Device.Image_Texture_Upload_Count,
         Image_Texture_Cache_Hit_Count =>
           Device.Image_Texture_Cache_Hit_Count,
         Atlas_Width => Device.Atlas_Width,
         Atlas_Height => Device.Atlas_Height,
         Atlas_Bytes => Device.Atlas_Bytes,
         Atlas_Upload_Count => Device.Atlas_Upload_Count,
         Fence_Deferred_Upload_Count =>
           Device.Fence_Deferred_Upload_Count,
         Swapchain_Width    => Device.Swapchain_Width,
         Swapchain_Height   => Device.Swapchain_Height,
         Last_Status        => Device.Last_Status);
   end Diagnostics;

   function Image_Status_Label
     (Diagnostics : Device_Diagnostic_Snapshot) return String
   is
      function Protocol_Name return String is
      begin
         case Diagnostics.Uploaded_Image_Protocol is
            when RM.Image_Sixel =>
               return "sixel";
            when RM.Image_Kitty =>
               return "kitty";
            when RM.Image_ITerm2 =>
               return "iTerm2";
         end case;
      end Protocol_Name;

   begin
      if Diagnostics.Uploaded_Image_Command_Count = 0 then
         return "";
      end if;

      return
        "uploaded image " & Protocol_Name
        & " size=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Width)
        & "x" & Trimmed_Natural (Diagnostics.Uploaded_Image_Height)
        & (if Diagnostics.Uploaded_Image_Pixel_Width > 0
           and then Diagnostics.Uploaded_Image_Pixel_Height > 0
           then
             " pixels=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Pixel_Width)
             & "x" & Trimmed_Natural (Diagnostics.Uploaded_Image_Pixel_Height)
             & " format=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Raw_Format)
           else "")
        & " vertices=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Vertex_Count)
        & " payload=" & Trimmed_Natural (Diagnostics.Uploaded_Image_Payload_Length)
        & RM.Image_Payload_Status_Suffix
            (Diagnostics.Uploaded_Image_Payload_Preview_Complete)
        & " preview="
        & Trimmed_Natural (Diagnostics.Uploaded_Image_Decoded_Preview_Length)
        & "/"
        & Trimmed_Natural (Diagnostics.Uploaded_Image_Encoded_Preview_Length)
        & Terminal.Common.Status.Preview_Bytes_Label
            (Diagnostics.Uploaded_Image_Decoded_Preview_Bytes,
             Diagnostics.Uploaded_Image_Decoded_Preview_Length)
        & " texture="
        & VS.Texture_Source_Label (Diagnostics.Uploaded_Image_Texture_Source)
        & (if Diagnostics.Uploaded_Image_Placeholder
           then " placeholder"
           else " textured")
        & (if Diagnostics.Uploaded_Image_Texture_Downgraded
           then " downgraded"
           else "")
        & (if Diagnostics.Uploaded_Image_Preview_Decode_Complete
           then " decoded"
           else " partial")
        & RM.Image_Decode_Status_Suffix
            (Diagnostics.Uploaded_Image_Decode_Status);
   end Image_Status_Label;

   function Image_Texture_Status_Label
     (Diagnostics : Device_Diagnostic_Snapshot) return String
   is
   begin
      if Diagnostics.Uploaded_Image_Command_Count = 0 then
         return "";
      elsif Diagnostics.Uploaded_Image_Texture_Downgraded then
         return
           "device image texture downgraded; texture="
           & VS.Texture_Source_Label (Diagnostics.Uploaded_Image_Texture_Source)
           & " vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count);
      elsif Diagnostics.Uploaded_Image_Texture_Source = VS.Texture_Image
        and then not Diagnostics.Uploaded_Image_Placeholder
      then
         return
           "device image texture ready; vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count);
      else
         return
           "device image texture unavailable; texture="
           & VS.Texture_Source_Label (Diagnostics.Uploaded_Image_Texture_Source)
           & " vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count);
      end if;
   end Image_Texture_Status_Label;

   function Image_Texture_Resource_Status_Label
     (Diagnostics : Device_Diagnostic_Snapshot) return String
   is
   begin
      if Diagnostics.Uploaded_Image_Command_Count = 0 then
         return "";
      elsif Diagnostics.Uploaded_Image_Texture_Source /= VS.Texture_Image then
         return
           "device image texture resources inactive; texture="
           & VS.Texture_Source_Label (Diagnostics.Uploaded_Image_Texture_Source)
           & " descriptors="
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Bound_Count)
           & "/"
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Capacity);
      elsif Diagnostics.Uploaded_Image_Texture_Vertex_Count = 0 then
         return
           "device image texture resources unavailable; vertices=0"
           & " descriptors="
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Bound_Count)
           & "/"
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Capacity);
      elsif Diagnostics.Image_Texture_Descriptor_Bound_Count >= 2 then
         return
           "device image texture resources ready; vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count)
           & " descriptors="
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Bound_Count)
           & "/"
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Capacity);
      else
         return
           "device image texture resources pending; descriptor=atlas-only"
           & " vertices="
           & Trimmed_Natural (Diagnostics.Uploaded_Image_Texture_Vertex_Count)
           & " descriptors="
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Bound_Count)
           & "/"
           & Trimmed_Natural (Diagnostics.Image_Texture_Descriptor_Capacity);
      end if;
   end Image_Texture_Resource_Status_Label;
end Terminal.App.Vulkan_Device;
