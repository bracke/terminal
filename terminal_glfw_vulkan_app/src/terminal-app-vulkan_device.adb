with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with System.Address_To_Access_Conversions;
with Terminal.App.Shaders;

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
   Suboptimal_KHR : constant Vk.Result_T := Vk.Result_T (1_000_001_003);
   Error_Out_Of_Date_KHR : constant Vk.Result_T := Vk.Result_T (-1_000_001_004);
   Subpass_External : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32'Last;
   UInt32_Max : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32'Last;
   Packed_Vertex_Bytes : constant Interfaces.Unsigned_64 := 40;
   Max_Atlas_Bytes : constant := 16 * 1024 * 1024;
   Queue_Family_Ignored : constant Interfaces.Unsigned_32 :=
     Interfaces.Unsigned_32'Last;

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

   procedure Upload_Atlas_Data
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Bytes_Natural : Natural;
      Pixels        : System.Address;
      Dirty         : Boolean;
      Status        : out Create_Status);

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
   is
      Priority : aliased Interfaces.C.C_float := 1.0;
      Extension_Name : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("VK_KHR_swapchain");
      Extensions : Chars_Ptr_Array (1 .. 1) := (1 => Extension_Name);
      Queue_Info : aliased Vk.Device_Queue_Create_Info_T :=
        (s_Type             => Vk.STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
         p_Next             => System.Null_Address,
         flags              => 0,
         queue_Family_Index => Interfaces.Unsigned_32 (Choice.Queue_Family_Index),
         queue_Count        => 1,
         p_Queue_Priorities => Priority'Address);
      Create_Info : aliased Vk.Device_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_DEVICE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         queue_Create_Info_Count  => 1,
         p_Queue_Create_Infos     => Queue_Info'Address,
         enabled_Layer_Count      => 0,
         pp_Enabled_Layer_Names   => System.Null_Address,
         enabled_Extension_Count  => 1,
         pp_Enabled_Extension_Names => Extensions'Address,
         p_Enabled_Features       => System.Null_Address);
      Handle : aliased Vk.Device_T := System.Null_Address;
      Queue  : aliased Vk.Queue_T := System.Null_Address;
      Result : Vk.Result_T;
      Extension_Count : Natural := 0;

      procedure Reset_Device (Status_Value : Create_Status) is
      begin
         Device.Initialized := False;
         Device.Device := System.Null_Address;
         Device.Queue := System.Null_Address;
         Device.Swapchain := System.Null_Address;
         Device.Swapchain_Format := Vk.FORMAT_UNDEFINED;
         Device.Render_Pass := System.Null_Address;
         Device.Pipeline_Layout := System.Null_Address;
         Device.Graphics_Pipeline := System.Null_Address;
         Device.Descriptor_Set_Layout := System.Null_Address;
         Device.Descriptor_Pool := System.Null_Address;
         Device.Descriptor_Set := System.Null_Address;
         Device.Command_Pool := System.Null_Address;
         Device.Vertex_Buffer := System.Null_Address;
         Device.Vertex_Memory := System.Null_Address;
         Device.Color_MSAA_Image := System.Null_Address;
         Device.Color_MSAA_Memory := System.Null_Address;
         Device.Color_MSAA_View := System.Null_Address;
         Device.Color_Sample_Count := Vk.SAMPLE_COUNT_1_BIT;
         Device.Atlas_Image := System.Null_Address;
         Device.Atlas_Memory := System.Null_Address;
         Device.Atlas_View := System.Null_Address;
         Device.Atlas_Sampler := System.Null_Address;
         Device.Swapchain_Images := (others => System.Null_Address);
         Device.Swapchain_Views := (others => System.Null_Address);
         Device.Framebuffers := (others => System.Null_Address);
         Device.Command_Buffers := (others => System.Null_Address);
         Device.Image_Available := (others => System.Null_Address);
         Device.Render_Finished := (others => System.Null_Address);
         Device.In_Flight := (others => System.Null_Address);
         Device.Queue_Family_Index := 0;
         Device.Swapchain_Image_Count := 0;
         Device.Swapchain_View_Count := 0;
         Device.Framebuffer_Count := 0;
         Device.Command_Buffer_Count := 0;
         Device.Sync_Frame_Count := 0;
         Device.Vertex_Buffer_Bytes := 0;
         Device.Uploaded_Vertex_Count := 0;
         Device.Uploaded_Text_Run_Count := 0;
         Device.Uploaded_Shaped_Glyph_Count := 0;
         Device.Swapchain_Width := 0;
         Device.Swapchain_Height := 0;
         Device.Last_Status := Status_Value;
      end Reset_Device;

      function Create_Image_Views
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Image_Count : aliased Interfaces.Unsigned_32 := 0;
         Result : Vk.Result_T;
      begin
         Result :=
           Vk.Get_Swapchain_Images_KHR
             (Handle,
              Device.Swapchain,
              Image_Count'Address,
              System.Null_Address);
         if Result /= Vk.SUCCESS or else Image_Count = 0 then
            return Get_Swapchain_Images_Failed;
         end if;

         if Image_Count > Interfaces.Unsigned_32 (Max_Swapchain_Images) then
            return Too_Many_Swapchain_Images;
         end if;

         Result :=
           Vk.Get_Swapchain_Images_KHR
             (Handle,
              Device.Swapchain,
              Image_Count'Address,
              Device.Swapchain_Images'Address);
         if Result /= Vk.SUCCESS then
            return Get_Swapchain_Images_Failed;
         end if;

         Device.Swapchain_Image_Count := Natural (Image_Count);

         for I in 1 .. Natural (Image_Count) loop
            declare
               View : aliased Vk.Image_View_T := System.Null_Address;
               Create_Info : aliased Vk.Image_View_Create_Info_T :=
                 (s_Type             => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                  p_Next             => System.Null_Address,
                  flags              => 0,
                  image              => Device.Swapchain_Images (I),
                  view_Type          => Vk.IMAGE_VIEW_TYPE_2D,
                  format             => Device.Swapchain_Format,
                  components         =>
                    (r => Vk.COMPONENT_SWIZZLE_IDENTITY,
                     g => Vk.COMPONENT_SWIZZLE_IDENTITY,
                     b => Vk.COMPONENT_SWIZZLE_IDENTITY,
                     a => Vk.COMPONENT_SWIZZLE_IDENTITY),
                  subresource_Range  =>
                    (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                     base_Mip_Level   => 0,
                     level_Count      => 1,
                     base_Array_Layer => 0,
                     layer_Count      => 1));
            begin
               Result :=
                 Vk.Create_Image_View
                   (Handle, Create_Info'Address, System.Null_Address, View'Address);
               if Result /= Vk.SUCCESS or else View = System.Null_Address then
                  for J in 1 .. Device.Swapchain_View_Count loop
                     Vk.Destroy_Image_View
                       (Handle, Device.Swapchain_Views (J), System.Null_Address);
                     Device.Swapchain_Views (J) := System.Null_Address;
                  end loop;
                  Device.Swapchain_View_Count := 0;
                  return Create_Image_View_Failed;
               end if;

               Device.Swapchain_Views (I) := View;
               Device.Swapchain_View_Count := I;
            end;
         end loop;

         return Ok;
      end Create_Image_Views;

      procedure Destroy_Framebuffers (Handle : Vk.Device_T) is
      begin
         for I in 1 .. Device.Framebuffer_Count loop
            if Device.Framebuffers (I) /= System.Null_Address then
               Vk.Destroy_Framebuffer
                 (Handle, Device.Framebuffers (I), System.Null_Address);
               Device.Framebuffers (I) := System.Null_Address;
            end if;
         end loop;
         Device.Framebuffer_Count := 0;
      end Destroy_Framebuffers;

      procedure Destroy_Image_Views (Handle : Vk.Device_T) is
      begin
         for I in 1 .. Device.Swapchain_View_Count loop
            if Device.Swapchain_Views (I) /= System.Null_Address then
               Vk.Destroy_Image_View
                 (Handle, Device.Swapchain_Views (I), System.Null_Address);
               Device.Swapchain_Views (I) := System.Null_Address;
            end if;
         end loop;
         Device.Swapchain_View_Count := 0;
      end Destroy_Image_Views;

      procedure Destroy_Color_MSAA_Target (Handle : Vk.Device_T) is
      begin
         if Device.Color_MSAA_View /= System.Null_Address then
            Vk.Destroy_Image_View
              (Handle, Device.Color_MSAA_View, System.Null_Address);
            Device.Color_MSAA_View := System.Null_Address;
         end if;

         if Device.Color_MSAA_Image /= System.Null_Address then
            Vk.Destroy_Image
              (Handle, Device.Color_MSAA_Image, System.Null_Address);
            Device.Color_MSAA_Image := System.Null_Address;
         end if;

         if Device.Color_MSAA_Memory /= System.Null_Address then
            Vk.Free_Memory
              (Handle, Device.Color_MSAA_Memory, System.Null_Address);
            Device.Color_MSAA_Memory := System.Null_Address;
         end if;

         Device.Color_Sample_Count := Vk.SAMPLE_COUNT_1_BIT;
      end Destroy_Color_MSAA_Target;

      function Choose_Color_Sample_Count
        return Vk.Sample_Count_Flag_Bits_T;

      function Create_Color_MSAA_Target
        (Handle  : Vk.Device_T;
         Format  : Vk.Format_T;
         Samples : Vk.Sample_Count_Flag_Bits_T)
         return Create_Status;

      procedure Destroy_Sync (Handle : Vk.Device_T) is
      begin
         for I in 1 .. Device.Sync_Frame_Count loop
            if Device.In_Flight (I) /= System.Null_Address then
               Vk.Destroy_Fence (Handle, Device.In_Flight (I), System.Null_Address);
               Device.In_Flight (I) := System.Null_Address;
            end if;
            if Device.Render_Finished (I) /= System.Null_Address then
               Vk.Destroy_Semaphore
                 (Handle, Device.Render_Finished (I), System.Null_Address);
               Device.Render_Finished (I) := System.Null_Address;
            end if;
            if Device.Image_Available (I) /= System.Null_Address then
               Vk.Destroy_Semaphore
                 (Handle, Device.Image_Available (I), System.Null_Address);
               Device.Image_Available (I) := System.Null_Address;
            end if;
         end loop;
         Device.Sync_Frame_Count := 0;
      end Destroy_Sync;

      procedure Destroy_Command_Resources (Handle : Vk.Device_T) is
      begin
         if Device.Command_Pool /= System.Null_Address then
            if Device.Command_Buffer_Count > 0 then
               Vk.Free_Command_Buffers
                 (Handle,
                  Device.Command_Pool,
                  Interfaces.Unsigned_32 (Device.Command_Buffer_Count),
                  Device.Command_Buffers'Address);
            end if;

            Vk.Destroy_Command_Pool
              (Handle, Device.Command_Pool, System.Null_Address);
         end if;

         Device.Command_Pool := System.Null_Address;
         Device.Command_Buffers := (others => System.Null_Address);
         Device.Command_Buffer_Count := 0;
      end Destroy_Command_Resources;

      procedure Destroy_Descriptor_Resources (Handle : Vk.Device_T) is
      begin
         if Device.Atlas_Sampler /= System.Null_Address then
            Vk.Destroy_Sampler (Handle, Device.Atlas_Sampler, System.Null_Address);
            Device.Atlas_Sampler := System.Null_Address;
         end if;

         if Device.Descriptor_Pool /= System.Null_Address then
            Vk.Destroy_Descriptor_Pool
              (Handle, Device.Descriptor_Pool, System.Null_Address);
            Device.Descriptor_Pool := System.Null_Address;
            Device.Descriptor_Set := System.Null_Address;
         end if;

         if Device.Descriptor_Set_Layout /= System.Null_Address then
            Vk.Destroy_Descriptor_Set_Layout
              (Handle, Device.Descriptor_Set_Layout, System.Null_Address);
            Device.Descriptor_Set_Layout := System.Null_Address;
         end if;
      end Destroy_Descriptor_Resources;

      function Create_Descriptor_Resources
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Binding : aliased Vk.Descriptor_Set_Layout_Binding_T :=
           (binding => 0,
            descriptor_Type => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            descriptor_Count => 1,
            stage_Flags => Vk.SHADER_STAGE_FRAGMENT_BIT,
            p_Immutable_Samplers => System.Null_Address);
         Layout_Info : aliased Vk.Descriptor_Set_Layout_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            binding_Count => 1,
            p_Bindings => Binding'Address);
         Layout : aliased Vk.Descriptor_Set_Layout_T := System.Null_Address;
         Pool_Size : aliased Descriptor_Pool_Size_Array :=
           (1 =>
              (type_F => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
               descriptor_Count => 1));
         Pool_Info : aliased Vk.Descriptor_Pool_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            max_Sets => 1,
            pool_Size_Count => Pool_Size'Length,
            p_Pool_Sizes => Pool_Size'Address);
         Pool : aliased Vk.Descriptor_Pool_T := System.Null_Address;
         Layouts : aliased Descriptor_Set_Layout_Array := (1 => System.Null_Address);
         Allocate_Info : aliased Vk.Descriptor_Set_Allocate_Info_T;
         Descriptor_Set : aliased Vk.Descriptor_Set_T := System.Null_Address;
         Sampler_Info : aliased Vk.Sampler_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            mag_Filter => Vk.FILTER_LINEAR,
            min_Filter => Vk.FILTER_LINEAR,
            mipmap_Mode => Vk.SAMPLER_MIPMAP_MODE_NEAREST,
            address_Mode_U => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            address_Mode_V => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            address_Mode_W => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            mip_Lod_Bias => 0.0,
            anisotropy_Enable => 0,
            max_Anisotropy => 1.0,
            compare_Enable => 0,
            compare_Op => Vk.COMPARE_OP_ALWAYS,
            min_Lod => 0.0,
            max_Lod => 0.0,
            border_Color => Vk.BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
            unnormalized_Coordinates => 0);
         Sampler : aliased Vk.Sampler_T := System.Null_Address;
         Result : Vk.Result_T;
      begin
         Result :=
           Vk.Create_Descriptor_Set_Layout
             (Handle, Layout_Info'Address, System.Null_Address, Layout'Address);
         if Result /= Vk.SUCCESS or else Layout = System.Null_Address then
            return Create_Descriptor_Set_Layout_Failed;
         end if;
         Device.Descriptor_Set_Layout := Layout;

         Result :=
           Vk.Create_Descriptor_Pool
             (Handle, Pool_Info'Address, System.Null_Address, Pool'Address);
         if Result /= Vk.SUCCESS or else Pool = System.Null_Address then
            Destroy_Descriptor_Resources (Handle);
            return Create_Descriptor_Pool_Failed;
         end if;
         Device.Descriptor_Pool := Pool;

         Layouts (1) := Device.Descriptor_Set_Layout;
         Allocate_Info :=
           (s_Type => Vk.STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            p_Next => System.Null_Address,
            descriptor_Pool => Device.Descriptor_Pool,
            descriptor_Set_Count => 1,
            p_Set_Layouts => Layouts'Address);
         Result :=
           Vk.Allocate_Descriptor_Sets
             (Handle, Allocate_Info'Address, Descriptor_Set'Address);
         if Result /= Vk.SUCCESS or else Descriptor_Set = System.Null_Address then
            Destroy_Descriptor_Resources (Handle);
            return Allocate_Descriptor_Set_Failed;
         end if;
         Device.Descriptor_Set := Descriptor_Set;

         Result :=
           Vk.Create_Sampler
             (Handle, Sampler_Info'Address, System.Null_Address, Sampler'Address);
         if Result /= Vk.SUCCESS or else Sampler = System.Null_Address then
            Destroy_Descriptor_Resources (Handle);
            return Create_Atlas_Sampler_Failed;
         end if;
         Device.Atlas_Sampler := Sampler;

         return Ok;
      end Create_Descriptor_Resources;

      function Create_Pipeline_Layout
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Set_Layouts : aliased Descriptor_Set_Layout_Array :=
           (1 => Device.Descriptor_Set_Layout);
         Layout_Info : aliased Vk.Pipeline_Layout_Create_Info_T :=
           (s_Type                   => Vk.STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            p_Next                   => System.Null_Address,
            flags                    => 0,
            set_Layout_Count         => 1,
            p_Set_Layouts            => Set_Layouts'Address,
            push_Constant_Range_Count => 0,
            p_Push_Constant_Ranges   => System.Null_Address);
         Layout : aliased Vk.Pipeline_Layout_T := System.Null_Address;
         Result : constant Vk.Result_T :=
           Vk.Create_Pipeline_Layout
             (Handle, Layout_Info'Address, System.Null_Address, Layout'Address);
      begin
         if Result /= Vk.SUCCESS or else Layout = System.Null_Address then
            return Create_Pipeline_Layout_Failed;
         end if;

         Device.Pipeline_Layout := Layout;
         return Ok;
      end Create_Pipeline_Layout;

      function Create_Shader_Module
        (Handle : Vk.Device_T;
         Code   : Shaders.Shader_Code;
         Module : out Vk.Shader_Module_T)
         return Create_Status
      is
         Create_Info : aliased Vk.Shader_Module_Create_Info_T :=
           (s_Type    => Vk.STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            p_Next    => System.Null_Address,
            flags     => 0,
            code_Size => Interfaces.C.size_t (Shaders.Byte_Size (Code)),
            p_Code    => Shaders.Address (Code));
         Shader : aliased Vk.Shader_Module_T := System.Null_Address;
         Result : constant Vk.Result_T :=
           Vk.Create_Shader_Module
             (Handle, Create_Info'Address, System.Null_Address, Shader'Address);
      begin
         Module := System.Null_Address;
         if Result /= Vk.SUCCESS or else Shader = System.Null_Address then
            return Create_Shader_Module_Failed;
         end if;

         Module := Shader;
         return Ok;
      end Create_Shader_Module;

      function Create_Graphics_Pipeline
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Vertex_Code : Shaders.Shader_Code;
         Fragment_Code : Shaders.Shader_Code;
         Load_Status : Shaders.Load_Status;
         Vertex_Module : Vk.Shader_Module_T := System.Null_Address;
         Fragment_Module : Vk.Shader_Module_T := System.Null_Address;
         Module_Status : Create_Status;
         Main_Name : aliased Interfaces.C.char_array := Interfaces.C.To_C ("main");
         Stages : aliased Shader_Stage_Array :=
           (1 =>
              (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags  => 0,
               stage  => Vk.SHADER_STAGE_VERTEX_BIT,
               module => System.Null_Address,
               p_Name => Main_Name'Address,
               p_Specialization_Info => System.Null_Address),
            2 =>
              (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags  => 0,
               stage  => Vk.SHADER_STAGE_FRAGMENT_BIT,
               module => System.Null_Address,
               p_Name => Main_Name'Address,
               p_Specialization_Info => System.Null_Address));
         Binding : aliased Vk.Vertex_Input_Binding_Description_T :=
           (binding    => 0,
            stride     => 40,
            input_Rate => Vk.VERTEX_INPUT_RATE_VERTEX);
         Attributes : aliased Vertex_Attribute_Array :=
           (1 =>
              (location => 0, binding => 0,
               format => Vk.FORMAT_R32G32_SFLOAT, offset => 0),
            2 =>
              (location => 1, binding => 0,
               format => Vk.FORMAT_R32G32_SFLOAT, offset => 8),
            3 =>
              (location => 2, binding => 0,
               format => Vk.FORMAT_R32G32B32A32_SFLOAT, offset => 16),
            4 =>
              (location => 3, binding => 0,
               format => Vk.FORMAT_R32_SFLOAT, offset => 32),
            5 =>
              (location => 4, binding => 0,
               format => Vk.FORMAT_R32_SFLOAT, offset => 36));
         Vertex_Input : aliased Vk.Pipeline_Vertex_Input_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            vertex_Binding_Description_Count => 1,
            p_Vertex_Binding_Descriptions => Binding'Address,
            vertex_Attribute_Description_Count => Attributes'Length,
            p_Vertex_Attribute_Descriptions => Attributes'Address);
         Input_Assembly : aliased Vk.Pipeline_Input_Assembly_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            topology => Vk.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            primitive_Restart_Enable => 0);
         Viewport_State : aliased Vk.Pipeline_Viewport_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            viewport_Count => 1,
            p_Viewports => System.Null_Address,
            scissor_Count => 1,
            p_Scissors => System.Null_Address);
         Rasterization : aliased Vk.Pipeline_Rasterization_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            depth_Clamp_Enable => 0,
            rasterizer_Discard_Enable => 0,
            polygon_Mode => Vk.POLYGON_MODE_FILL,
            cull_Mode => Vk.CULL_MODE_NONE,
            front_Face => Vk.FRONT_FACE_COUNTER_CLOCKWISE,
            depth_Bias_Enable => 0,
            depth_Bias_Constant_Factor => 0.0,
            depth_Bias_Clamp => 0.0,
            depth_Bias_Slope_Factor => 0.0,
            line_Width => 1.0);
         Multisample : aliased Vk.Pipeline_Multisample_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            rasterization_Samples => Device.Color_Sample_Count,
            sample_Shading_Enable => 0,
            min_Sample_Shading => 1.0,
            p_Sample_Mask => System.Null_Address,
            alpha_To_Coverage_Enable => 0,
            alpha_To_One_Enable => 0);
         Color_Attachment : aliased Vk.Pipeline_Color_Blend_Attachment_State_T :=
           (blend_Enable => 1,
            src_Color_Blend_Factor => Vk.BLEND_FACTOR_SRC_ALPHA,
            dst_Color_Blend_Factor => Vk.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            color_Blend_Op => Vk.BLEND_OP_ADD,
            src_Alpha_Blend_Factor => Vk.BLEND_FACTOR_ONE,
            dst_Alpha_Blend_Factor => Vk.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            alpha_Blend_Op => Vk.BLEND_OP_ADD,
            color_Write_Mask =>
              Vk.COLOR_COMPONENT_R_BIT or Vk.COLOR_COMPONENT_G_BIT or
              Vk.COLOR_COMPONENT_B_BIT or Vk.COLOR_COMPONENT_A_BIT);
         Color_Blend : aliased Vk.Pipeline_Color_Blend_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            logic_Op_Enable => 0,
            logic_Op => Vk.LOGIC_OP_COPY,
            attachment_Count => 1,
            p_Attachments => Color_Attachment'Address,
            blend_Constants => (others => 0.0));
         Dynamic_States : aliased Dynamic_State_Array :=
           (1 => Vk.DYNAMIC_STATE_VIEWPORT,
            2 => Vk.DYNAMIC_STATE_SCISSOR);
         Dynamic_State : aliased Vk.Pipeline_Dynamic_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            dynamic_State_Count => Dynamic_States'Length,
            p_Dynamic_States => Dynamic_States'Address);
         Pipeline_Info : aliased Vk.Graphics_Pipeline_Create_Info_T;
         Pipeline : aliased Vk.Pipeline_T := System.Null_Address;
         Result : Vk.Result_T;
      begin
         Shaders.Load ("terminal.vert.spv", Vertex_Code, Load_Status);
         if Load_Status /= Shaders.Ok then
            return Shader_Load_Failed;
         end if;

         Shaders.Load ("terminal.frag.spv", Fragment_Code, Load_Status);
         if Load_Status /= Shaders.Ok then
            Shaders.Release (Vertex_Code);
            return Shader_Load_Failed;
         end if;

         Module_Status := Create_Shader_Module (Handle, Vertex_Code, Vertex_Module);
         Shaders.Release (Vertex_Code);
         if Module_Status /= Ok then
            Shaders.Release (Fragment_Code);
            return Module_Status;
         end if;

         Module_Status := Create_Shader_Module (Handle, Fragment_Code, Fragment_Module);
         Shaders.Release (Fragment_Code);
         if Module_Status /= Ok then
            Vk.Destroy_Shader_Module (Handle, Vertex_Module, System.Null_Address);
            return Module_Status;
         end if;

         Stages (1).module := Vertex_Module;
         Stages (2).module := Fragment_Module;
         Pipeline_Info :=
           (s_Type => Vk.STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            stage_Count => Stages'Length,
            p_Stages => Stages'Address,
            p_Vertex_Input_State => Vertex_Input'Address,
            p_Input_Assembly_State => Input_Assembly'Address,
            p_Tessellation_State => System.Null_Address,
            p_Viewport_State => Viewport_State'Address,
            p_Rasterization_State => Rasterization'Address,
            p_Multisample_State => Multisample'Address,
            p_Depth_Stencil_State => System.Null_Address,
            p_Color_Blend_State => Color_Blend'Address,
            p_Dynamic_State => Dynamic_State'Address,
            layout => Device.Pipeline_Layout,
            render_Pass => Device.Render_Pass,
            subpass => 0,
            base_Pipeline_Handle => System.Null_Address,
            base_Pipeline_Index => Interfaces.Integer_32'(-1));

         Result :=
           Vk.Create_Graphics_Pipelines
             (Handle,
              System.Null_Address,
              1,
              Pipeline_Info'Address,
              System.Null_Address,
              Pipeline'Address);

         Vk.Destroy_Shader_Module (Handle, Fragment_Module, System.Null_Address);
         Vk.Destroy_Shader_Module (Handle, Vertex_Module, System.Null_Address);

         if Result /= Vk.SUCCESS or else Pipeline = System.Null_Address then
            return Create_Graphics_Pipeline_Failed;
         end if;

         Device.Graphics_Pipeline := Pipeline;
         return Ok;
      end Create_Graphics_Pipeline;

      function Create_Render_Pass_And_Framebuffers
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Samples : constant Vk.Sample_Count_Flag_Bits_T :=
           Choose_Color_Sample_Count;
         MSAA_On : constant Boolean := Samples /= Vk.SAMPLE_COUNT_1_BIT;
         Color_Attachment : aliased Vk.Attachment_Description_T :=
           (flags           => 0,
            format          => Device.Swapchain_Format,
            samples         => Samples,
            load_Op         => Vk.ATTACHMENT_LOAD_OP_CLEAR,
            store_Op        =>
              (if MSAA_On
               then Vk.ATTACHMENT_STORE_OP_DONT_CARE
               else Vk.ATTACHMENT_STORE_OP_STORE),
            stencil_Load_Op => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
            stencil_Store_Op => Vk.ATTACHMENT_STORE_OP_DONT_CARE,
            initial_Layout  => Vk.IMAGE_LAYOUT_UNDEFINED,
            final_Layout    =>
              (if MSAA_On
               then Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
               else Image_Layout_Present_Source));
         Resolve_Attachment : aliased Vk.Attachment_Description_T :=
           (flags           => 0,
            format          => Device.Swapchain_Format,
            samples         => Vk.SAMPLE_COUNT_1_BIT,
            load_Op         => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
            store_Op        => Vk.ATTACHMENT_STORE_OP_STORE,
            stencil_Load_Op => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
            stencil_Store_Op => Vk.ATTACHMENT_STORE_OP_DONT_CARE,
            initial_Layout  => Vk.IMAGE_LAYOUT_UNDEFINED,
            final_Layout    => Image_Layout_Present_Source);
         Attachments : aliased Attachment_Array (1 .. 2) :=
           (1 => Color_Attachment,
            2 => Resolve_Attachment);
         Color_Reference : aliased Vk.Attachment_Reference_T :=
           (attachment => 0,
            layout     => Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
         Resolve_Reference : aliased Vk.Attachment_Reference_T :=
           (attachment => 1,
            layout     => Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
         Subpass : aliased Vk.Subpass_Description_T :=
           (flags                    => 0,
            pipeline_Bind_Point      => Vk.PIPELINE_BIND_POINT_GRAPHICS,
            input_Attachment_Count   => 0,
            p_Input_Attachments      => System.Null_Address,
            color_Attachment_Count   => 1,
            p_Color_Attachments      => Color_Reference'Address,
            p_Resolve_Attachments    =>
              (if MSAA_On then Resolve_Reference'Address else System.Null_Address),
            p_Depth_Stencil_Attachment => System.Null_Address,
            preserve_Attachment_Count => 0,
            p_Preserve_Attachments   => System.Null_Address);
         Dependency : aliased Vk.Subpass_Dependency_T :=
           (src_Subpass      => Subpass_External,
            dst_Subpass      => 0,
            src_Stage_Mask   => Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            dst_Stage_Mask   => Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            src_Access_Mask  => 0,
            dst_Access_Mask  =>
              Vk.ACCESS_COLOR_ATTACHMENT_READ_BIT or
              Vk.ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            dependency_Flags => Vk.DEPENDENCY_BY_REGION_BIT);
         Render_Info : aliased Vk.Render_Pass_Create_Info_T :=
           (s_Type           => Vk.STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            p_Next           => System.Null_Address,
            flags            => 0,
            attachment_Count => (if MSAA_On then 2 else 1),
            p_Attachments    => Attachments'Address,
            subpass_Count    => 1,
            p_Subpasses      => Subpass'Address,
            dependency_Count => 1,
            p_Dependencies   => Dependency'Address);
         Render_Pass : aliased Vk.Render_Pass_T := System.Null_Address;
         Result : Vk.Result_T;
      begin
         if Device.Swapchain_View_Count = 0
           or else Device.Swapchain_Width = 0
           or else Device.Swapchain_Height = 0
         then
            return Create_Framebuffer_Failed;
         end if;

         Device.Color_Sample_Count := Samples;
         declare
            Target_Status : constant Create_Status :=
              Create_Color_MSAA_Target
                (Handle, Device.Swapchain_Format, Device.Color_Sample_Count);
         begin
            if Target_Status /= Ok then
               return Target_Status;
            end if;
         end;

         Result :=
           Vk.Create_Render_Pass
             (Handle, Render_Info'Address, System.Null_Address, Render_Pass'Address);
         if Result /= Vk.SUCCESS or else Render_Pass = System.Null_Address then
            Destroy_Color_MSAA_Target (Handle);
            return Create_Render_Pass_Failed;
         end if;

         Device.Render_Pass := Render_Pass;

         for I in 1 .. Device.Swapchain_View_Count loop
            declare
               Attachments : aliased Image_View_Array (1 .. 2) :=
                 (1 => System.Null_Address,
                  2 => System.Null_Address);
               Framebuffer : aliased Vk.Framebuffer_T := System.Null_Address;
               FB_Info : aliased Vk.Framebuffer_Create_Info_T :=
                 (s_Type           => Vk.STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                  p_Next           => System.Null_Address,
                  flags            => 0,
                  render_Pass      => Device.Render_Pass,
                  attachment_Count => (if MSAA_On then 2 else 1),
                  p_Attachments    => Attachments'Address,
                  width            => Interfaces.Unsigned_32 (Device.Swapchain_Width),
                  height           => Interfaces.Unsigned_32 (Device.Swapchain_Height),
                  layers           => 1);
            begin
               if MSAA_On then
                  Attachments (1) := Device.Color_MSAA_View;
                  Attachments (2) := Device.Swapchain_Views (I);
               else
                  Attachments (1) := Device.Swapchain_Views (I);
               end if;
               Result :=
                 Vk.Create_Framebuffer
                   (Handle, FB_Info'Address, System.Null_Address, Framebuffer'Address);
               if Result /= Vk.SUCCESS or else Framebuffer = System.Null_Address then
                  Destroy_Framebuffers (Handle);
                  Vk.Destroy_Render_Pass
                    (Handle, Device.Render_Pass, System.Null_Address);
                  Device.Render_Pass := System.Null_Address;
                  Destroy_Color_MSAA_Target (Handle);
                  return Create_Framebuffer_Failed;
               end if;

               Device.Framebuffers (I) := Framebuffer;
               Device.Framebuffer_Count := I;
            end;
         end loop;

         return Ok;
      end Create_Render_Pass_And_Framebuffers;

      function Create_Command_Resources_And_Sync
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Pool_Info : aliased Vk.Command_Pool_Create_Info_T :=
           (s_Type             => Vk.STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            p_Next             => System.Null_Address,
            flags              => Vk.COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            queue_Family_Index =>
              Interfaces.Unsigned_32 (Device.Queue_Family_Index));
         Pool : aliased Vk.Command_Pool_T := System.Null_Address;
         Result : Vk.Result_T;
      begin
         if Device.Framebuffer_Count = 0 then
            return Allocate_Command_Buffers_Failed;
         end if;

         Result :=
           Vk.Create_Command_Pool
             (Handle, Pool_Info'Address, System.Null_Address, Pool'Address);
         if Result /= Vk.SUCCESS or else Pool = System.Null_Address then
            return Create_Command_Pool_Failed;
         end if;

         Device.Command_Pool := Pool;

         declare
            Allocate_Info : aliased Vk.Command_Buffer_Allocate_Info_T :=
              (s_Type               => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
               p_Next               => System.Null_Address,
               command_Pool         => Device.Command_Pool,
               level                => Vk.COMMAND_BUFFER_LEVEL_PRIMARY,
               command_Buffer_Count =>
                 Interfaces.Unsigned_32 (Device.Framebuffer_Count));
         begin
            Result :=
              Vk.Allocate_Command_Buffers
                (Handle, Allocate_Info'Address, Device.Command_Buffers'Address);
            if Result /= Vk.SUCCESS then
               Destroy_Command_Resources (Handle);
               return Allocate_Command_Buffers_Failed;
            end if;

            Device.Command_Buffer_Count := Device.Framebuffer_Count;
         end;

         declare
            Semaphore_Info : aliased Vk.Semaphore_Create_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags  => 0);
            Fence_Info : aliased Vk.Fence_Create_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_FENCE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags  => Vk.FENCE_CREATE_SIGNALED_BIT);
         begin
            for I in 1 .. Device.Framebuffer_Count loop
               declare
                  Image_Sem : aliased Vk.Semaphore_T := System.Null_Address;
                  Render_Sem : aliased Vk.Semaphore_T := System.Null_Address;
                  Fence : aliased Vk.Fence_T := System.Null_Address;
               begin
                  Result :=
                    Vk.Create_Semaphore
                      (Handle,
                       Semaphore_Info'Address,
                       System.Null_Address,
                       Image_Sem'Address);
                  if Result /= Vk.SUCCESS or else Image_Sem = System.Null_Address then
                     Destroy_Sync (Handle);
                     Destroy_Command_Resources (Handle);
                     return Create_Sync_Failed;
                  end if;

                  Result :=
                    Vk.Create_Semaphore
                      (Handle,
                       Semaphore_Info'Address,
                       System.Null_Address,
                       Render_Sem'Address);
                  if Result /= Vk.SUCCESS or else Render_Sem = System.Null_Address then
                     Vk.Destroy_Semaphore (Handle, Image_Sem, System.Null_Address);
                     Destroy_Sync (Handle);
                     Destroy_Command_Resources (Handle);
                     return Create_Sync_Failed;
                  end if;

                  Result :=
                    Vk.Create_Fence
                      (Handle,
                       Fence_Info'Address,
                       System.Null_Address,
                       Fence'Address);
                  if Result /= Vk.SUCCESS or else Fence = System.Null_Address then
                     Vk.Destroy_Semaphore (Handle, Render_Sem, System.Null_Address);
                     Vk.Destroy_Semaphore (Handle, Image_Sem, System.Null_Address);
                     Destroy_Sync (Handle);
                     Destroy_Command_Resources (Handle);
                     return Create_Sync_Failed;
                  end if;

                  Device.Image_Available (I) := Image_Sem;
                  Device.Render_Finished (I) := Render_Sem;
                  Device.In_Flight (I) := Fence;
                  Device.Sync_Frame_Count := I;
               end;
            end loop;
         end;

         return Ok;
      end Create_Command_Resources_And_Sync;

      function Select_Surface_Format
        (Format_Count : Interfaces.Unsigned_32;
         Formats      : Surface_Format_Array)
         return Vk.Surface_Format_KHR_T
      is
      begin
         if Format_Count = 1 and then Formats (1).format = Vk.FORMAT_UNDEFINED then
            return
              (format      => Vk.FORMAT_B8G8R8A8_SRGB,
               color_Space => Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR);
         end if;

         for I in 1 .. Natural (Format_Count) loop
            if Formats (I).format = Vk.FORMAT_B8G8R8A8_SRGB
              and then Formats (I).color_Space = Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR
            then
               return Formats (I);
            end if;
         end loop;

         for I in 1 .. Natural (Format_Count) loop
            if Formats (I).format = Vk.FORMAT_B8G8R8A8_UNORM
              and then Formats (I).color_Space = Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR
            then
               return Formats (I);
            end if;
         end loop;

         return Formats (1);
      end Select_Surface_Format;

      function Select_Present_Mode
        (Mode_Count : Interfaces.Unsigned_32;
         Modes      : Present_Mode_Array)
         return Vk.Present_Mode_KHR_T
      is
      begin
         for I in 1 .. Natural (Mode_Count) loop
            if Modes (I) = Vk.PRESENT_MODE_MAILBOX_KHR then
               return Vk.PRESENT_MODE_MAILBOX_KHR;
            end if;
         end loop;

         return Vk.PRESENT_MODE_FIFO_KHR;
      end Select_Present_Mode;

      function Select_Extent
        (Capabilities : Vk.Surface_Capabilities_KHR_T)
         return Vk.Extent2_D_T
      is
         Width : Interfaces.Unsigned_32;
         Height : Interfaces.Unsigned_32;
      begin
         if Capabilities.current_Extent.width /= UInt32_Max then
            return Capabilities.current_Extent;
         end if;

         Width :=
           (if Desired_Width = 0
            then 960
            else Interfaces.Unsigned_32 (Desired_Width));
         Height :=
           (if Desired_Height = 0
            then 600
            else Interfaces.Unsigned_32 (Desired_Height));

         return
           (width  =>
              Clamp_U32
                (Width,
                 Capabilities.min_Image_Extent.width,
                 Capabilities.max_Image_Extent.width),
            height =>
              Clamp_U32
                (Height,
                 Capabilities.min_Image_Extent.height,
                 Capabilities.max_Image_Extent.height));
      end Select_Extent;

      function Choose_Image_Count
        (Capabilities : Vk.Surface_Capabilities_KHR_T)
         return Interfaces.Unsigned_32
      is
         Count : Interfaces.Unsigned_32 := Capabilities.min_Image_Count + 1;
      begin
         if Capabilities.max_Image_Count > 0 then
            Count := U32_Min (Count, Capabilities.max_Image_Count);
         end if;
         return Count;
      end Choose_Image_Count;

      function Choose_Composite_Alpha
        (Capabilities : Vk.Surface_Capabilities_KHR_T)
         return Vk.Composite_Alpha_Flag_Bits_KHR_T is
      begin
         if (Capabilities.supported_Composite_Alpha
             and Vk.COMPOSITE_ALPHA_OPAQUE_BIT_KHR) /= 0
         then
            return Vk.COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
         elsif (Capabilities.supported_Composite_Alpha
                and Vk.COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR) /= 0
         then
            return Vk.COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR;
         elsif (Capabilities.supported_Composite_Alpha
                and Vk.COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR) /= 0
         then
            return Vk.COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR;
         else
            return Vk.COMPOSITE_ALPHA_INHERIT_BIT_KHR;
         end if;
      end Choose_Composite_Alpha;

      function Choose_Color_Sample_Count
        return Vk.Sample_Count_Flag_Bits_T
      is
         Properties : aliased Vk.Physical_Device_Properties_T;
         Counts     : Vk.Sample_Count_Flags_T;
      begin
         Vk.Get_Physical_Device_Properties
           (Choice.Physical_Device, Properties'Address);
         Counts := Properties.limits.framebuffer_Color_Sample_Counts;

         if (Counts and Vk.SAMPLE_COUNT_8_BIT) /= 0 then
            return Vk.SAMPLE_COUNT_8_BIT;
         elsif (Counts and Vk.SAMPLE_COUNT_4_BIT) /= 0 then
            return Vk.SAMPLE_COUNT_4_BIT;
         elsif (Counts and Vk.SAMPLE_COUNT_2_BIT) /= 0 then
            return Vk.SAMPLE_COUNT_2_BIT;
         else
            return Vk.SAMPLE_COUNT_1_BIT;
         end if;
      end Choose_Color_Sample_Count;

      function Create_Color_MSAA_Target
        (Handle  : Vk.Device_T;
         Format  : Vk.Format_T;
         Samples : Vk.Sample_Count_Flag_Bits_T)
         return Create_Status
      is
         Memory_Properties : aliased Vk.Physical_Device_Memory_Properties_T;
         Image : aliased Vk.Image_T := System.Null_Address;
         Image_Memory : aliased Vk.Device_Memory_T := System.Null_Address;
         Image_View : aliased Vk.Image_View_T := System.Null_Address;
         Requirements : aliased Vk.Memory_Requirements_T;
         Memory_Type_Index : Interfaces.Unsigned_32 := 0;
         Result : Vk.Result_T;
      begin
         if Samples = Vk.SAMPLE_COUNT_1_BIT then
            return Ok;
         end if;

         declare
            Image_Info : aliased Vk.Image_Create_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags => 0,
               image_Type => Vk.IMAGE_TYPE_2D,
               format => Format,
               extent =>
                 (width => Interfaces.Unsigned_32 (Device.Swapchain_Width),
                  height => Interfaces.Unsigned_32 (Device.Swapchain_Height),
                  depth => 1),
               mip_Levels => 1,
               array_Layers => 1,
               samples => Samples,
               tiling => Vk.IMAGE_TILING_OPTIMAL,
               usage => Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
               sharing_Mode => Vk.SHARING_MODE_EXCLUSIVE,
               queue_Family_Index_Count => 0,
               p_Queue_Family_Indices => System.Null_Address,
               initial_Layout => Vk.IMAGE_LAYOUT_UNDEFINED);
         begin
            Result :=
              Vk.Create_Image
                (Handle, Image_Info'Address, System.Null_Address, Image'Address);
            if Result /= Vk.SUCCESS or else Image = System.Null_Address then
               return Create_Color_Target_Failed;
            end if;
         end;

         Vk.Get_Image_Memory_Requirements
           (Handle, Image, Requirements'Address);
         Vk.Get_Physical_Device_Memory_Properties
           (Choice.Physical_Device, Memory_Properties'Address);
         if not Has_Memory_Type
           (Memory_Properties, Requirements.memory_Type_Bits, 0, Memory_Type_Index)
         then
            Vk.Destroy_Image (Handle, Image, System.Null_Address);
            return Create_Color_Target_Failed;
         end if;

         declare
            Allocate_Info : aliased Vk.Memory_Allocate_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
               p_Next => System.Null_Address,
               allocation_Size => Requirements.size,
               memory_Type_Index => Memory_Type_Index);
         begin
            Result :=
              Vk.Allocate_Memory
                (Handle,
                 Allocate_Info'Address,
                 System.Null_Address,
                 Image_Memory'Address);
            if Result /= Vk.SUCCESS or else Image_Memory = System.Null_Address then
               Vk.Destroy_Image (Handle, Image, System.Null_Address);
               return Create_Color_Target_Failed;
            end if;
         end;

         Result := Vk.Bind_Image_Memory (Handle, Image, Image_Memory, 0);
         if Result /= Vk.SUCCESS then
            Vk.Free_Memory (Handle, Image_Memory, System.Null_Address);
            Vk.Destroy_Image (Handle, Image, System.Null_Address);
            return Create_Color_Target_Failed;
         end if;

         declare
            View_Info : aliased Vk.Image_View_Create_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
               p_Next => System.Null_Address,
               flags => 0,
               image => Image,
               view_Type => Vk.IMAGE_VIEW_TYPE_2D,
               format => Format,
               components =>
                 (r => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  g => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  b => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  a => Vk.COMPONENT_SWIZZLE_IDENTITY),
               subresource_Range =>
                 (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
                  base_Mip_Level => 0,
                  level_Count => 1,
                  base_Array_Layer => 0,
                  layer_Count => 1));
         begin
            Result :=
              Vk.Create_Image_View
                (Handle,
                 View_Info'Address,
                 System.Null_Address,
                 Image_View'Address);
            if Result /= Vk.SUCCESS or else Image_View = System.Null_Address then
               Vk.Free_Memory (Handle, Image_Memory, System.Null_Address);
               Vk.Destroy_Image (Handle, Image, System.Null_Address);
               return Create_Color_Target_Failed;
            end if;
         end;

         Device.Color_MSAA_Image := Image;
         Device.Color_MSAA_Memory := Image_Memory;
         Device.Color_MSAA_View := Image_View;
         return Ok;
      end Create_Color_MSAA_Target;

      function Create_Swapchain
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Capabilities : aliased Vk.Surface_Capabilities_KHR_T;
         Format_Count : aliased Interfaces.Unsigned_32 := 0;
         Present_Mode_Count : aliased Interfaces.Unsigned_32 := 0;
         Formats : Surface_Format_Array;
         Modes : Present_Mode_Array;
         Chosen_Format : Vk.Surface_Format_KHR_T;
         Chosen_Mode : Vk.Present_Mode_KHR_T;
         Chosen_Extent : Vk.Extent2_D_T;
         Chosen_Image_Count : Interfaces.Unsigned_32;
         Swapchain : aliased Vk.Swapchain_KHR_T := System.Null_Address;
         Swap_Info : aliased Vk.Swapchain_Create_Info_KHR_T;
         Result : Vk.Result_T;
      begin
         if Surface = System.Null_Address then
            return Surface_Query_Failed;
         end if;

         Result :=
           Vk.Get_Physical_Device_Surface_Capabilities_KHR
             (Choice.Physical_Device, Surface, Capabilities'Address);
         if Result /= Vk.SUCCESS then
            return Surface_Query_Failed;
         end if;

         if (Capabilities.supported_Usage_Flags and
             Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT) = 0
         then
            return Create_Swapchain_Failed;
         end if;

         Result :=
           Vk.Get_Physical_Device_Surface_Formats_KHR
             (Choice.Physical_Device,
              Surface,
              Format_Count'Address,
              System.Null_Address);
         if Result /= Vk.SUCCESS or else Format_Count = 0 then
            return Surface_Query_Failed;
         end if;

         Format_Count :=
           U32_Min (Format_Count, Interfaces.Unsigned_32 (Max_Surface_Formats));
         Result :=
           Vk.Get_Physical_Device_Surface_Formats_KHR
             (Choice.Physical_Device, Surface, Format_Count'Address, Formats'Address);
         if Result /= Vk.SUCCESS then
            return Surface_Query_Failed;
         end if;

         Result :=
           Vk.Get_Physical_Device_Surface_Present_Modes_KHR
             (Choice.Physical_Device,
              Surface,
              Present_Mode_Count'Address,
              System.Null_Address);
         if Result /= Vk.SUCCESS or else Present_Mode_Count = 0 then
            return Surface_Query_Failed;
         end if;

         Present_Mode_Count :=
           U32_Min (Present_Mode_Count, Interfaces.Unsigned_32 (Max_Present_Modes));
         Result :=
           Vk.Get_Physical_Device_Surface_Present_Modes_KHR
             (Choice.Physical_Device,
              Surface,
              Present_Mode_Count'Address,
              Modes'Address);
         if Result /= Vk.SUCCESS then
            return Surface_Query_Failed;
         end if;

         Chosen_Format := Select_Surface_Format (Format_Count, Formats);
         Chosen_Mode := Select_Present_Mode (Present_Mode_Count, Modes);
         Chosen_Extent := Select_Extent (Capabilities);
         if Chosen_Extent.width = 0 or else Chosen_Extent.height = 0 then
            return Invalid_Extent;
         end if;
         Chosen_Image_Count := Choose_Image_Count (Capabilities);

         Swap_Info :=
           (s_Type                   => Swapchain_Create_Info_Structure,
            p_Next                   => System.Null_Address,
            flags                    => 0,
            surface                  => Surface,
            min_Image_Count          => Chosen_Image_Count,
            image_Format             => Chosen_Format.format,
            image_Color_Space        => Chosen_Format.color_Space,
            image_Extent             => Chosen_Extent,
            image_Array_Layers       => 1,
            image_Usage              => Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            image_Sharing_Mode       => Vk.SHARING_MODE_EXCLUSIVE,
            queue_Family_Index_Count => 0,
            p_Queue_Family_Indices   => System.Null_Address,
            pre_Transform            => Capabilities.current_Transform,
            composite_Alpha          => Choose_Composite_Alpha (Capabilities),
            present_Mode             => Chosen_Mode,
            clipped                  => 1,
            old_Swapchain            => System.Null_Address);

         Result :=
           Vk.Create_Swapchain_KHR
             (Handle, Swap_Info'Address, System.Null_Address, Swapchain'Address);
         if Result /= Vk.SUCCESS or else Swapchain = System.Null_Address then
            return Create_Swapchain_Failed;
         end if;

         Device.Swapchain := Swapchain;
         Device.Swapchain_Format := Chosen_Format.format;
         Device.Swapchain_Width := Natural (Chosen_Extent.width);
         Device.Swapchain_Height := Natural (Chosen_Extent.height);
         return Ok;
      end Create_Swapchain;
   begin
      Reset_Device (Selection_Not_Ready);

      if not Choice.Selected or else Choice.Physical_Device = System.Null_Address then
         Interfaces.C.Strings.Free (Extension_Name);
         Status := Selection_Not_Ready;
         Device.Last_Status := Status;
         return;
      end if;

      if not Device_Supports_Swapchain (Choice.Physical_Device, Extension_Count) then
         Interfaces.C.Strings.Free (Extension_Name);
         Status := Swapchain_Extension_Missing;
         Device.Last_Status := Status;
         return;
      end if;

      Result :=
        Vk.Create_Device
          (Choice.Physical_Device,
           Create_Info'Address,
           System.Null_Address,
           Handle'Address);
      Interfaces.C.Strings.Free (Extension_Name);

      if Result /= Vk.SUCCESS or else Handle = System.Null_Address then
         Status := Create_Device_Failed;
         Device.Last_Status := Status;
         return;
      end if;

      Vk.Get_Device_Queue
        (Handle,
         Interfaces.Unsigned_32 (Choice.Queue_Family_Index),
         0,
         Queue'Address);

      if Queue = System.Null_Address then
         Vk.Destroy_Device (Handle, System.Null_Address);
         Status := Queue_Unavailable;
         Device.Last_Status := Status;
         return;
      end if;

      Device.Initialized := True;
      Device.Device := Handle;
      Device.Queue := Queue;
      Device.Queue_Family_Index := Choice.Queue_Family_Index;

      declare
         Swapchain_Status : constant Create_Status := Create_Swapchain (Handle);
      begin
         if Swapchain_Status /= Ok then
            Vk.Destroy_Device (Handle, System.Null_Address);
            Reset_Device (Swapchain_Status);
            Status := Swapchain_Status;
            return;
         end if;
      end;

      declare
         View_Status : constant Create_Status := Create_Image_Views (Handle);
      begin
         if View_Status /= Ok then
            if Device.Swapchain /= System.Null_Address then
               Vk.Destroy_Swapchain_KHR
                 (Handle, Device.Swapchain, System.Null_Address);
            end if;
            Vk.Destroy_Device (Handle, System.Null_Address);
            Reset_Device (View_Status);
            Status := View_Status;
            return;
         end if;
      end;

      declare
         Render_Status : constant Create_Status :=
           Create_Render_Pass_And_Framebuffers (Handle);
      begin
         if Render_Status /= Ok then
            Destroy_Image_Views (Handle);
            if Device.Swapchain /= System.Null_Address then
               Vk.Destroy_Swapchain_KHR
                 (Handle, Device.Swapchain, System.Null_Address);
            end if;
            Vk.Destroy_Device (Handle, System.Null_Address);
            Reset_Device (Render_Status);
            Status := Render_Status;
            return;
         end if;
      end;

      declare
         Command_Status : constant Create_Status :=
           Create_Command_Resources_And_Sync (Handle);
      begin
         if Command_Status /= Ok then
            Destroy_Framebuffers (Handle);
            if Device.Render_Pass /= System.Null_Address then
               Vk.Destroy_Render_Pass
                 (Handle, Device.Render_Pass, System.Null_Address);
            end if;
            Destroy_Color_MSAA_Target (Handle);
            Destroy_Image_Views (Handle);
            if Device.Swapchain /= System.Null_Address then
               Vk.Destroy_Swapchain_KHR
                 (Handle, Device.Swapchain, System.Null_Address);
            end if;
            Vk.Destroy_Device (Handle, System.Null_Address);
            Reset_Device (Command_Status);
            Status := Command_Status;
            return;
         end if;
      end;

      declare
         Descriptor_Status : constant Create_Status :=
           Create_Descriptor_Resources (Handle);
      begin
         if Descriptor_Status /= Ok then
            Destroy_Sync (Handle);
            Destroy_Command_Resources (Handle);
            Destroy_Framebuffers (Handle);
            if Device.Render_Pass /= System.Null_Address then
               Vk.Destroy_Render_Pass
                 (Handle, Device.Render_Pass, System.Null_Address);
            end if;
            Destroy_Color_MSAA_Target (Handle);
            Destroy_Image_Views (Handle);
            if Device.Swapchain /= System.Null_Address then
               Vk.Destroy_Swapchain_KHR
                 (Handle, Device.Swapchain, System.Null_Address);
            end if;
            Vk.Destroy_Device (Handle, System.Null_Address);
            Reset_Device (Descriptor_Status);
            Status := Descriptor_Status;
            return;
         end if;
      end;

      declare
         Layout_Status : constant Create_Status := Create_Pipeline_Layout (Handle);
      begin
         if Layout_Status /= Ok then
            Destroy_Descriptor_Resources (Handle);
            Destroy_Sync (Handle);
            Destroy_Command_Resources (Handle);
            Destroy_Framebuffers (Handle);
            if Device.Render_Pass /= System.Null_Address then
               Vk.Destroy_Render_Pass
                 (Handle, Device.Render_Pass, System.Null_Address);
            end if;
            Destroy_Color_MSAA_Target (Handle);
            Destroy_Image_Views (Handle);
            if Device.Swapchain /= System.Null_Address then
               Vk.Destroy_Swapchain_KHR
                 (Handle, Device.Swapchain, System.Null_Address);
            end if;
            Vk.Destroy_Device (Handle, System.Null_Address);
            Reset_Device (Layout_Status);
            Status := Layout_Status;
            return;
         end if;
      end;

      declare
         Default_Atlas_Pixel : aliased Interfaces.Unsigned_8 := 255;
         Atlas_Status : Create_Status;
      begin
         Upload_Atlas_Data
           (Device        => Device,
            Choice        => Choice,
            Width         => 1,
            Height        => 1,
            Bytes_Natural => 1,
            Pixels        => Default_Atlas_Pixel'Address,
            Dirty         => True,
            Status        => Atlas_Status);
         if Atlas_Status /= Ok then
            if Device.Pipeline_Layout /= System.Null_Address then
               Vk.Destroy_Pipeline_Layout
                 (Handle, Device.Pipeline_Layout, System.Null_Address);
            end if;
            Destroy_Descriptor_Resources (Handle);
            Destroy_Sync (Handle);
            Destroy_Command_Resources (Handle);
            Destroy_Framebuffers (Handle);
            if Device.Render_Pass /= System.Null_Address then
               Vk.Destroy_Render_Pass
                 (Handle, Device.Render_Pass, System.Null_Address);
            end if;
            Destroy_Color_MSAA_Target (Handle);
            Destroy_Image_Views (Handle);
            if Device.Swapchain /= System.Null_Address then
               Vk.Destroy_Swapchain_KHR
                 (Handle, Device.Swapchain, System.Null_Address);
            end if;
            Vk.Destroy_Device (Handle, System.Null_Address);
            Reset_Device (Atlas_Status);
            Status := Atlas_Status;
            return;
         end if;
      end;

      declare
         Pipeline_Status : constant Create_Status := Create_Graphics_Pipeline (Handle);
      begin
         if Pipeline_Status /= Ok then
            if Device.Pipeline_Layout /= System.Null_Address then
               Vk.Destroy_Pipeline_Layout
                 (Handle, Device.Pipeline_Layout, System.Null_Address);
            end if;
            Destroy_Atlas_Image (Device);
            Destroy_Descriptor_Resources (Handle);
            Destroy_Sync (Handle);
            Destroy_Command_Resources (Handle);
            Destroy_Framebuffers (Handle);
            if Device.Render_Pass /= System.Null_Address then
               Vk.Destroy_Render_Pass
                 (Handle, Device.Render_Pass, System.Null_Address);
            end if;
            Destroy_Color_MSAA_Target (Handle);
            Destroy_Image_Views (Handle);
            if Device.Swapchain /= System.Null_Address then
               Vk.Destroy_Swapchain_KHR
                 (Handle, Device.Swapchain, System.Null_Address);
            end if;
            Vk.Destroy_Device (Handle, System.Null_Address);
            Reset_Device (Pipeline_Status);
            Status := Pipeline_Status;
            return;
         end if;
      end;

      Device.Last_Status := Ok;
      Status := Ok;
   end Create_Logical_Device;

   procedure Finalize (Device : in out Logical_Device) is
   begin
      if Device.Device /= System.Null_Address then
         declare
            Result : constant Vk.Result_T := Vk.Device_Wait_Idle (Device.Device);
            pragma Unreferenced (Result);
         begin
            for I in 1 .. Device.Sync_Frame_Count loop
               if Device.In_Flight (I) /= System.Null_Address then
                  Vk.Destroy_Fence
                    (Device.Device, Device.In_Flight (I), System.Null_Address);
               end if;
               if Device.Render_Finished (I) /= System.Null_Address then
                  Vk.Destroy_Semaphore
                    (Device.Device, Device.Render_Finished (I), System.Null_Address);
               end if;
               if Device.Image_Available (I) /= System.Null_Address then
                  Vk.Destroy_Semaphore
                    (Device.Device, Device.Image_Available (I), System.Null_Address);
               end if;
            end loop;

            if Device.Command_Pool /= System.Null_Address then
               if Device.Command_Buffer_Count > 0 then
                  Vk.Free_Command_Buffers
                    (Device.Device,
                     Device.Command_Pool,
                     Interfaces.Unsigned_32 (Device.Command_Buffer_Count),
                     Device.Command_Buffers'Address);
               end if;
               Vk.Destroy_Command_Pool
                 (Device.Device, Device.Command_Pool, System.Null_Address);
            end if;

            if Device.Vertex_Buffer /= System.Null_Address then
               Vk.Destroy_Buffer
                 (Device.Device, Device.Vertex_Buffer, System.Null_Address);
            end if;

            if Device.Vertex_Memory /= System.Null_Address then
               Vk.Free_Memory
                 (Device.Device, Device.Vertex_Memory, System.Null_Address);
            end if;

            if Device.Atlas_View /= System.Null_Address then
               Vk.Destroy_Image_View
                 (Device.Device, Device.Atlas_View, System.Null_Address);
            end if;

            if Device.Atlas_Image /= System.Null_Address then
               Vk.Destroy_Image
                 (Device.Device, Device.Atlas_Image, System.Null_Address);
            end if;

            if Device.Atlas_Memory /= System.Null_Address then
               Vk.Free_Memory
                 (Device.Device, Device.Atlas_Memory, System.Null_Address);
            end if;

            if Device.Atlas_Sampler /= System.Null_Address then
               Vk.Destroy_Sampler
                 (Device.Device, Device.Atlas_Sampler, System.Null_Address);
            end if;

            if Device.Graphics_Pipeline /= System.Null_Address then
               Vk.Destroy_Pipeline
                 (Device.Device, Device.Graphics_Pipeline, System.Null_Address);
            end if;

            if Device.Pipeline_Layout /= System.Null_Address then
               Vk.Destroy_Pipeline_Layout
                 (Device.Device, Device.Pipeline_Layout, System.Null_Address);
            end if;

            if Device.Descriptor_Pool /= System.Null_Address then
               Vk.Destroy_Descriptor_Pool
                 (Device.Device, Device.Descriptor_Pool, System.Null_Address);
            end if;

            if Device.Descriptor_Set_Layout /= System.Null_Address then
               Vk.Destroy_Descriptor_Set_Layout
                 (Device.Device, Device.Descriptor_Set_Layout, System.Null_Address);
            end if;

            for I in 1 .. Device.Framebuffer_Count loop
               if Device.Framebuffers (I) /= System.Null_Address then
                  Vk.Destroy_Framebuffer
                    (Device.Device, Device.Framebuffers (I), System.Null_Address);
               end if;
            end loop;

            if Device.Render_Pass /= System.Null_Address then
               Vk.Destroy_Render_Pass
                 (Device.Device, Device.Render_Pass, System.Null_Address);
            end if;

            if Device.Color_MSAA_View /= System.Null_Address then
               Vk.Destroy_Image_View
                 (Device.Device, Device.Color_MSAA_View, System.Null_Address);
            end if;

            if Device.Color_MSAA_Image /= System.Null_Address then
               Vk.Destroy_Image
                 (Device.Device, Device.Color_MSAA_Image, System.Null_Address);
            end if;

            if Device.Color_MSAA_Memory /= System.Null_Address then
               Vk.Free_Memory
                 (Device.Device, Device.Color_MSAA_Memory, System.Null_Address);
            end if;

            for I in 1 .. Device.Swapchain_View_Count loop
               if Device.Swapchain_Views (I) /= System.Null_Address then
                  Vk.Destroy_Image_View
                    (Device.Device, Device.Swapchain_Views (I), System.Null_Address);
               end if;
            end loop;

            if Device.Swapchain /= System.Null_Address then
               Vk.Destroy_Swapchain_KHR
                 (Device.Device, Device.Swapchain, System.Null_Address);
            end if;
            Vk.Destroy_Device (Device.Device, System.Null_Address);
         end;
      end if;

      Device.Initialized := False;
      Device.Device := System.Null_Address;
      Device.Queue := System.Null_Address;
      Device.Swapchain := System.Null_Address;
      Device.Swapchain_Format := Vk.FORMAT_UNDEFINED;
      Device.Render_Pass := System.Null_Address;
      Device.Pipeline_Layout := System.Null_Address;
      Device.Graphics_Pipeline := System.Null_Address;
      Device.Descriptor_Set_Layout := System.Null_Address;
      Device.Descriptor_Pool := System.Null_Address;
      Device.Descriptor_Set := System.Null_Address;
      Device.Command_Pool := System.Null_Address;
      Device.Vertex_Buffer := System.Null_Address;
      Device.Vertex_Memory := System.Null_Address;
      Device.Color_MSAA_Image := System.Null_Address;
      Device.Color_MSAA_Memory := System.Null_Address;
      Device.Color_MSAA_View := System.Null_Address;
      Device.Color_Sample_Count := Vk.SAMPLE_COUNT_1_BIT;
      Device.Atlas_Image := System.Null_Address;
      Device.Atlas_Memory := System.Null_Address;
      Device.Atlas_View := System.Null_Address;
      Device.Atlas_Sampler := System.Null_Address;
      Device.Swapchain_Images := (others => System.Null_Address);
      Device.Swapchain_Views := (others => System.Null_Address);
      Device.Framebuffers := (others => System.Null_Address);
      Device.Command_Buffers := (others => System.Null_Address);
      Device.Image_Available := (others => System.Null_Address);
      Device.Render_Finished := (others => System.Null_Address);
      Device.In_Flight := (others => System.Null_Address);
      Device.Queue_Family_Index := 0;
      Device.Swapchain_Image_Count := 0;
      Device.Swapchain_View_Count := 0;
      Device.Framebuffer_Count := 0;
      Device.Command_Buffer_Count := 0;
      Device.Sync_Frame_Count := 0;
      Device.Vertex_Buffer_Bytes := 0;
      Device.Uploaded_Vertex_Count := 0;
      Device.Uploaded_Text_Run_Count := 0;
      Device.Uploaded_Shaped_Glyph_Count := 0;
      Device.Rendered_Frame_Count := 0;
      Device.Current_Frame := 1;
      Device.Atlas_Width := 0;
      Device.Atlas_Height := 0;
      Device.Atlas_Bytes := 0;
      Device.Atlas_Upload_Count := 0;
      Device.Swapchain_Width := 0;
      Device.Swapchain_Height := 0;
      Device.Last_Status := Selection_Not_Ready;
   end Finalize;

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

   procedure Upload_Atlas_Data
     (Device        : in out Logical_Device;
      Choice        : Selection;
      Width         : Natural;
      Height        : Natural;
      Bytes_Natural : Natural;
      Pixels        : System.Address;
      Dirty         : Boolean;
      Status        : out Create_Status)
   is
      Bytes : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64 (Bytes_Natural);
      Image : aliased Vk.Image_T := System.Null_Address;
      Image_Memory : aliased Vk.Device_Memory_T := System.Null_Address;
      Image_View : aliased Vk.Image_View_T := System.Null_Address;
      Staging_Buffer : aliased Vk.Buffer_T := System.Null_Address;
      Staging_Memory : aliased Vk.Device_Memory_T := System.Null_Address;
      Data : aliased System.Address := System.Null_Address;
      Memory_Requirements : aliased Vk.Memory_Requirements_T;
      Memory_Properties : aliased Vk.Physical_Device_Memory_Properties_T;
      Memory_Type_Index : Interfaces.Unsigned_32 := 0;
      Result : Vk.Result_T;

      procedure Destroy_Staging is
      begin
         if Staging_Buffer /= System.Null_Address then
            Vk.Destroy_Buffer
              (Device.Device, Staging_Buffer, System.Null_Address);
            Staging_Buffer := System.Null_Address;
         end if;

         if Staging_Memory /= System.Null_Address then
            Vk.Free_Memory
              (Device.Device, Staging_Memory, System.Null_Address);
            Staging_Memory := System.Null_Address;
         end if;
      end Destroy_Staging;

      procedure Cleanup_New_Image is
      begin
         if Image_View /= System.Null_Address then
            Vk.Destroy_Image_View
              (Device.Device, Image_View, System.Null_Address);
            Image_View := System.Null_Address;
         end if;

         if Image /= System.Null_Address then
            Vk.Destroy_Image (Device.Device, Image, System.Null_Address);
            Image := System.Null_Address;
         end if;

         if Image_Memory /= System.Null_Address then
            Vk.Free_Memory
              (Device.Device, Image_Memory, System.Null_Address);
            Image_Memory := System.Null_Address;
         end if;
      end Cleanup_New_Image;
   begin
      if Width = 0
        or else Height = 0
        or else Bytes_Natural = 0
        or else Bytes_Natural > Max_Atlas_Bytes
        or else Pixels = System.Null_Address
      then
         Status := Atlas_Too_Large;
         return;
      end if;

      if not Dirty
        and then Device.Atlas_Image /= System.Null_Address
        and then Device.Atlas_Width = Width
        and then Device.Atlas_Height = Height
        and then Device.Atlas_Bytes = Bytes_Natural
      then
         Status := Ok;
         return;
      end if;

      Result := Vk.Queue_Wait_Idle (Device.Queue);
      if Result /= Vk.SUCCESS then
         Status := Copy_Atlas_Failed;
         return;
      end if;

      declare
         Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            size => Bytes,
            usage => Vk.BUFFER_USAGE_TRANSFER_SRC_BIT,
            sharing_Mode => Vk.SHARING_MODE_EXCLUSIVE,
            queue_Family_Index_Count => 0,
            p_Queue_Family_Indices => System.Null_Address);
      begin
         Result :=
           Vk.Create_Buffer
             (Device.Device,
              Buffer_Info'Address,
              System.Null_Address,
              Staging_Buffer'Address);
         if Result /= Vk.SUCCESS or else Staging_Buffer = System.Null_Address then
            Status := Create_Atlas_Staging_Buffer_Failed;
            return;
         end if;
      end;

      Vk.Get_Buffer_Memory_Requirements
        (Device.Device, Staging_Buffer, Memory_Requirements'Address);
      Vk.Get_Physical_Device_Memory_Properties
        (Choice.Physical_Device, Memory_Properties'Address);

      if not Has_Memory_Type
        (Memory_Properties,
         Memory_Requirements.memory_Type_Bits,
         Vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT or
           Vk.MEMORY_PROPERTY_HOST_COHERENT_BIT,
         Memory_Type_Index)
      then
         Destroy_Staging;
         Status := Allocate_Atlas_Staging_Memory_Failed;
         return;
      end if;

      declare
         Allocate_Info : aliased Vk.Memory_Allocate_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            p_Next => System.Null_Address,
            allocation_Size => Memory_Requirements.size,
            memory_Type_Index => Memory_Type_Index);
      begin
         Result :=
           Vk.Allocate_Memory
             (Device.Device,
              Allocate_Info'Address,
              System.Null_Address,
              Staging_Memory'Address);
         if Result /= Vk.SUCCESS or else Staging_Memory = System.Null_Address then
            Destroy_Staging;
            Status := Allocate_Atlas_Staging_Memory_Failed;
            return;
         end if;
      end;

      Result :=
        Vk.Bind_Buffer_Memory (Device.Device, Staging_Buffer, Staging_Memory, 0);
      if Result /= Vk.SUCCESS then
         Destroy_Staging;
         Status := Bind_Atlas_Staging_Buffer_Failed;
         return;
      end if;

      Result :=
        Vk.Map_Memory
          (Device.Device, Staging_Memory, 0, Bytes, 0, Data'Address);
      if Result /= Vk.SUCCESS or else Data = System.Null_Address then
         Destroy_Staging;
         Status := Map_Atlas_Staging_Buffer_Failed;
         return;
      end if;

      declare
         Source : constant Byte_Mapping.Object_Pointer :=
           Byte_Mapping.To_Pointer (Pixels);
         Target : constant Byte_Mapping.Object_Pointer :=
           Byte_Mapping.To_Pointer (Data);
      begin
         for I in 1 .. Bytes_Natural loop
            Target.all (I) := Source.all (I);
         end loop;
      end;
      Vk.Unmap_Memory (Device.Device, Staging_Memory);

      declare
         Image_Info : aliased Vk.Image_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            image_Type => Vk.IMAGE_TYPE_2D,
            format => Vk.FORMAT_R8_UNORM,
            extent =>
              (width => Interfaces.Unsigned_32 (Width),
               height => Interfaces.Unsigned_32 (Height),
               depth => 1),
            mip_Levels => 1,
            array_Layers => 1,
            samples => Vk.SAMPLE_COUNT_1_BIT,
            tiling => Vk.IMAGE_TILING_OPTIMAL,
            usage => Vk.IMAGE_USAGE_TRANSFER_DST_BIT or Vk.IMAGE_USAGE_SAMPLED_BIT,
            sharing_Mode => Vk.SHARING_MODE_EXCLUSIVE,
            queue_Family_Index_Count => 0,
            p_Queue_Family_Indices => System.Null_Address,
            initial_Layout => Vk.IMAGE_LAYOUT_UNDEFINED);
      begin
         Result :=
           Vk.Create_Image
             (Device.Device, Image_Info'Address, System.Null_Address, Image'Address);
         if Result /= Vk.SUCCESS or else Image = System.Null_Address then
            Destroy_Staging;
            Status := Create_Atlas_Image_Failed;
            return;
         end if;
      end;

      Vk.Get_Image_Memory_Requirements
        (Device.Device, Image, Memory_Requirements'Address);
      if not Has_Memory_Type
        (Memory_Properties, Memory_Requirements.memory_Type_Bits, 0, Memory_Type_Index)
      then
         Cleanup_New_Image;
         Destroy_Staging;
         Status := Allocate_Atlas_Memory_Failed;
         return;
      end if;

      declare
         Allocate_Info : aliased Vk.Memory_Allocate_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            p_Next => System.Null_Address,
            allocation_Size => Memory_Requirements.size,
            memory_Type_Index => Memory_Type_Index);
      begin
         Result :=
           Vk.Allocate_Memory
             (Device.Device,
              Allocate_Info'Address,
              System.Null_Address,
              Image_Memory'Address);
         if Result /= Vk.SUCCESS or else Image_Memory = System.Null_Address then
            Cleanup_New_Image;
            Destroy_Staging;
            Status := Allocate_Atlas_Memory_Failed;
            return;
         end if;
      end;

      Result := Vk.Bind_Image_Memory (Device.Device, Image, Image_Memory, 0);
      if Result /= Vk.SUCCESS then
         Cleanup_New_Image;
         Destroy_Staging;
         Status := Bind_Atlas_Image_Failed;
         return;
      end if;

      declare
         View_Info : aliased Vk.Image_View_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            image => Image,
            view_Type => Vk.IMAGE_VIEW_TYPE_2D,
            format => Vk.FORMAT_R8_UNORM,
            components =>
              (r => Vk.COMPONENT_SWIZZLE_IDENTITY,
               g => Vk.COMPONENT_SWIZZLE_IDENTITY,
               b => Vk.COMPONENT_SWIZZLE_IDENTITY,
               a => Vk.COMPONENT_SWIZZLE_IDENTITY),
            subresource_Range =>
              (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
               base_Mip_Level => 0,
               level_Count => 1,
               base_Array_Layer => 0,
               layer_Count => 1));
      begin
         Result :=
           Vk.Create_Image_View
             (Device.Device,
              View_Info'Address,
              System.Null_Address,
              Image_View'Address);
         if Result /= Vk.SUCCESS or else Image_View = System.Null_Address then
            Cleanup_New_Image;
            Destroy_Staging;
            Status := Create_Atlas_View_Failed;
            return;
         end if;
      end;

      declare
         Command_Buffer : constant Vk.Command_Buffer_T := Device.Command_Buffers (1);
         Begin_Info : aliased Vk.Command_Buffer_Begin_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            p_Next => System.Null_Address,
            flags => Vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            p_Inheritance_Info => System.Null_Address);
         To_Transfer : aliased Vk.Image_Memory_Barrier_T :=
           (s_Type => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            p_Next => System.Null_Address,
            src_Access_Mask => 0,
            dst_Access_Mask => Vk.ACCESS_TRANSFER_WRITE_BIT,
            old_Layout => Vk.IMAGE_LAYOUT_UNDEFINED,
            new_Layout => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            src_Queue_Family_Index => Queue_Family_Ignored,
            dst_Queue_Family_Index => Queue_Family_Ignored,
            image => Image,
            subresource_Range =>
              (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
               base_Mip_Level => 0,
               level_Count => 1,
               base_Array_Layer => 0,
               layer_Count => 1));
         Region : aliased Vk.Buffer_Image_Copy_T :=
           (buffer_Offset => 0,
            buffer_Row_Length => 0,
            buffer_Image_Height => 0,
            image_Subresource =>
              (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
               mip_Level => 0,
               base_Array_Layer => 0,
               layer_Count => 1),
            image_Offset => (x => 0, y => 0, z => 0),
            image_Extent =>
              (width => Interfaces.Unsigned_32 (Width),
               height => Interfaces.Unsigned_32 (Height),
               depth => 1));
         To_Shader : aliased Vk.Image_Memory_Barrier_T :=
           (s_Type => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            p_Next => System.Null_Address,
            src_Access_Mask => Vk.ACCESS_TRANSFER_WRITE_BIT,
            dst_Access_Mask => Vk.ACCESS_SHADER_READ_BIT,
            old_Layout => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            new_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            src_Queue_Family_Index => Queue_Family_Ignored,
            dst_Queue_Family_Index => Queue_Family_Ignored,
            image => Image,
            subresource_Range =>
              (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
               base_Mip_Level => 0,
               level_Count => 1,
               base_Array_Layer => 0,
               layer_Count => 1));
         Submit_Command_Buffers : aliased Command_Buffer_Submit_Array :=
           (1 => Command_Buffer);
         Submit_Info : aliased Vk.Submit_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_SUBMIT_INFO,
            p_Next => System.Null_Address,
            wait_Semaphore_Count => 0,
            p_Wait_Semaphores => System.Null_Address,
            p_Wait_Dst_Stage_Mask => System.Null_Address,
            command_Buffer_Count => 1,
            p_Command_Buffers => Submit_Command_Buffers'Address,
            signal_Semaphore_Count => 0,
            p_Signal_Semaphores => System.Null_Address);
      begin
         if Command_Buffer = System.Null_Address then
            Cleanup_New_Image;
            Destroy_Staging;
            Status := Copy_Atlas_Failed;
            return;
         end if;

         Result := Vk.Reset_Command_Buffer (Command_Buffer, 0);
         if Result /= Vk.SUCCESS then
            Cleanup_New_Image;
            Destroy_Staging;
            Status := Copy_Atlas_Failed;
            return;
         end if;

         Result := Vk.Begin_Command_Buffer (Command_Buffer, Begin_Info'Address);
         if Result /= Vk.SUCCESS then
            Cleanup_New_Image;
            Destroy_Staging;
            Status := Copy_Atlas_Failed;
            return;
         end if;

         Vk.Cmd_Pipeline_Barrier
           (Command_Buffer,
            Vk.PIPELINE_STAGE_TRANSFER_BIT,
            Vk.PIPELINE_STAGE_TRANSFER_BIT,
            0,
            0,
            System.Null_Address,
            0,
            System.Null_Address,
            1,
            To_Transfer'Address);
         Vk.Cmd_Copy_Buffer_To_Image
           (Command_Buffer,
            Staging_Buffer,
            Image,
            Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            Region'Address);
         Vk.Cmd_Pipeline_Barrier
           (Command_Buffer,
            Vk.PIPELINE_STAGE_TRANSFER_BIT,
            Vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            0,
            0,
            System.Null_Address,
            0,
            System.Null_Address,
            1,
            To_Shader'Address);

         Result := Vk.End_Command_Buffer (Command_Buffer);
         if Result /= Vk.SUCCESS then
            Cleanup_New_Image;
            Destroy_Staging;
            Status := Copy_Atlas_Failed;
            return;
         end if;

         Result :=
           Vk.Queue_Submit
             (Device.Queue, 1, Submit_Info'Address, System.Null_Address);
         if Result /= Vk.SUCCESS then
            Cleanup_New_Image;
            Destroy_Staging;
            Status := Copy_Atlas_Failed;
            return;
         end if;

         Result := Vk.Queue_Wait_Idle (Device.Queue);
         if Result /= Vk.SUCCESS then
            Cleanup_New_Image;
            Destroy_Staging;
            Status := Copy_Atlas_Failed;
            return;
         end if;
      end;

      declare
         Image_Info : aliased Vk.Descriptor_Image_Info_T :=
           (sampler => Device.Atlas_Sampler,
            image_View => Image_View,
            image_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
         Write : aliased Vk.Write_Descriptor_Set_T :=
           (s_Type => Vk.STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            p_Next => System.Null_Address,
            dst_Set => Device.Descriptor_Set,
            dst_Binding => 0,
            dst_Array_Element => 0,
            descriptor_Count => 1,
            descriptor_Type => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            p_Image_Info => Image_Info'Address,
            p_Buffer_Info => System.Null_Address,
            p_Texel_Buffer_View => System.Null_Address);
      begin
         Vk.Update_Descriptor_Sets
           (Device.Device, 1, Write'Address, 0, System.Null_Address);
      end;

      Destroy_Atlas_Image (Device);
      Device.Atlas_Image := Image;
      Device.Atlas_Memory := Image_Memory;
      Device.Atlas_View := Image_View;
      Device.Atlas_Width := Width;
      Device.Atlas_Height := Height;
      Device.Atlas_Bytes := Bytes_Natural;
      Device.Atlas_Upload_Count := Device.Atlas_Upload_Count + 1;
      Image := System.Null_Address;
      Image_Memory := System.Null_Address;
      Image_View := System.Null_Address;
      Destroy_Staging;
      Status := Ok;
   end Upload_Atlas_Data;

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

   procedure Upload
     (Device : in out Logical_Device;
      Choice : Selection;
      Batch  : VS.Submission_Batch;
      Status : out Create_Status)
   is
      Count : constant Natural := VS.Vertex_Count (Batch);
      Bytes : Interfaces.Unsigned_64;
      Data  : aliased System.Address := System.Null_Address;
      Result : Vk.Result_T;
   begin
      if not Device.Initialized
        or else not Choice.Selected
        or else VS.Vertices (Batch) = null
      then
         Status := Selection_Not_Ready;
         return;
      end if;

      if Count = 0 or else Count > Max_Upload_Vertices then
         Status := Vertex_Buffer_Too_Large;
         return;
      end if;

      if VS.Text_Atlas_Used (Batch) then
         Upload_Atlas (Device, Choice, Batch, Status);
         if Status /= Ok then
            return;
         end if;
      end if;

      Bytes := Interfaces.Unsigned_64 (Count) * Packed_Vertex_Bytes;
      Ensure_Vertex_Buffer (Device, Choice, Bytes, Status);
      if Status /= Ok then
         return;
      end if;

      Result :=
        Vk.Map_Memory
          (Device.Device,
           Device.Vertex_Memory,
           0,
           Bytes,
           0,
           Data'Address);
      if Result /= Vk.SUCCESS or else Data = System.Null_Address then
         Status := Map_Vertex_Buffer_Failed;
         return;
      end if;

      declare
         Mapped : constant Vertex_Mapping.Object_Pointer :=
           Vertex_Mapping.To_Pointer (Data);
      begin
         for I in 1 .. Count loop
            declare
               Source : constant VS.Vertex := VS.Vertices (Batch) (I);
            begin
               Mapped.all (I) :=
                 (X          => Interfaces.C.C_float (Source.X),
                  Y          => Interfaces.C.C_float (Source.Y),
                  U          => Interfaces.C.C_float (Source.U),
                  V          => Interfaces.C.C_float (Source.V),
                  R          => Interfaces.C.C_float (Source.Color.R),
                  G          => Interfaces.C.C_float (Source.Color.G),
                  B          => Interfaces.C.C_float (Source.Color.B),
                  A          => Interfaces.C.C_float (Source.Color.A),
                  Textured   => To_Float (Source.Textured),
                  Texture_ID =>
                    (if Source.Texture = VS.Texture_Text_Atlas then 1.0 else 0.0));
            end;
         end loop;
      end;

      Vk.Unmap_Memory (Device.Device, Device.Vertex_Memory);
      Device.Uploaded_Vertex_Count := Count;
      Device.Uploaded_Text_Run_Count := VS.Text_Run_Count (Batch);
      Device.Uploaded_Shaped_Glyph_Count := VS.Shaped_Glyph_Count (Batch);
      Status := Ok;
   end Upload;

   procedure Render
     (Device : in out Logical_Device;
      Status : out Render_Status)
   is
      Frame : Natural := Device.Current_Frame;
      Image_Index : aliased Interfaces.Unsigned_32 := 0;
      Result : Vk.Result_T;
   begin
      if not Device.Initialized
        or else Device.Swapchain = System.Null_Address
        or else Device.Render_Pass = System.Null_Address
        or else Device.Graphics_Pipeline = System.Null_Address
        or else Device.Vertex_Buffer = System.Null_Address
        or else Device.Command_Buffer_Count = 0
        or else Device.Sync_Frame_Count = 0
      then
         Status := Not_Initialized;
         return;
      end if;

      if Device.Uploaded_Vertex_Count = 0 then
         Status := No_Uploaded_Vertices;
         return;
      end if;

      if Frame = 0 or else Frame > Device.Sync_Frame_Count then
         Frame := 1;
      end if;

      Result :=
        Vk.Wait_For_Fences
          (Device.Device,
           1,
           Device.In_Flight (Frame)'Address,
           1,
           Interfaces.Unsigned_64'Last);
      if Result /= Vk.SUCCESS then
         Status := Wait_Fence_Failed;
         return;
      end if;

      Result :=
        Vk.Acquire_Next_Image_KHR
          (Device.Device,
           Device.Swapchain,
           Interfaces.Unsigned_64'Last,
           Device.Image_Available (Frame),
           System.Null_Address,
           Image_Index'Address);
      if Is_Swapchain_Stale (Result) then
         Status := Swapchain_Out_Of_Date;
         return;
      elsif Result /= Vk.SUCCESS then
         Status := Acquire_Image_Failed;
         return;
      end if;

      declare
         Image_Slot : constant Natural := Natural (Image_Index) + 1;
      begin
         if Image_Slot = 0
           or else Image_Slot > Device.Framebuffer_Count
           or else Image_Slot > Device.Command_Buffer_Count
         then
            Status := Acquire_Image_Failed;
            return;
         end if;

         declare
            Command_Buffer : constant Vk.Command_Buffer_T :=
              Device.Command_Buffers (Image_Slot);
            Begin_Info : aliased Vk.Command_Buffer_Begin_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
               p_Next => System.Null_Address,
               flags  => Vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
               p_Inheritance_Info => System.Null_Address);
            Clear_Value : aliased Vk.Clear_Value_T :=
              (Kind => 0,
               color =>
                 (Kind => 0,
                  float32 => (0 => 0.0, 1 => 0.0, 2 => 0.0, 3 => 1.0)));
            Render_Area : constant Vk.Rect2_D_T :=
              (offset => (x => 0, y => 0),
               extent =>
                 (width  => Interfaces.Unsigned_32 (Device.Swapchain_Width),
                  height => Interfaces.Unsigned_32 (Device.Swapchain_Height)));
            Render_Info : aliased Vk.Render_Pass_Begin_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
               p_Next => System.Null_Address,
               render_Pass => Device.Render_Pass,
               framebuffer => Device.Framebuffers (Image_Slot),
               render_Area => Render_Area,
               clear_Value_Count => 1,
               p_Clear_Values => Clear_Value'Address);
            Viewport : aliased Vk.Viewport_T :=
              (x => 0.0,
               y => 0.0,
               width => Interfaces.C.C_float (Device.Swapchain_Width),
               height => Interfaces.C.C_float (Device.Swapchain_Height),
               min_Depth => 0.0,
               max_Depth => 1.0);
            Scissor : aliased Vk.Rect2_D_T := Render_Area;
            Buffers : aliased Buffer_Binding_Array :=
              (1 => Device.Vertex_Buffer);
            Offsets : aliased Device_Size_Array := (1 => 0);
            Command_Buffers : aliased Command_Buffer_Submit_Array :=
              (1 => Command_Buffer);
            Wait_Semaphores : aliased Semaphore_Submit_Array :=
              (1 => Device.Image_Available (Frame));
            Signal_Semaphores : aliased Semaphore_Submit_Array :=
              (1 => Device.Render_Finished (Frame));
            Wait_Stages : aliased Pipeline_Stage_Array :=
              (1 => Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
            Submit_Info : aliased Vk.Submit_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_SUBMIT_INFO,
               p_Next => System.Null_Address,
               wait_Semaphore_Count => 1,
               p_Wait_Semaphores => Wait_Semaphores'Address,
               p_Wait_Dst_Stage_Mask => Wait_Stages'Address,
               command_Buffer_Count => 1,
               p_Command_Buffers => Command_Buffers'Address,
               signal_Semaphore_Count => 1,
               p_Signal_Semaphores => Signal_Semaphores'Address);
            Swapchains : aliased Swapchain_Submit_Array :=
              (1 => Device.Swapchain);
            Image_Indices : aliased Image_Index_Array := (1 => Image_Index);
            Present_Info : aliased Vk.Present_Info_KHR_T :=
              (s_Type => Present_Info_Structure,
               p_Next => System.Null_Address,
               wait_Semaphore_Count => 1,
               p_Wait_Semaphores => Signal_Semaphores'Address,
               swapchain_Count => 1,
               p_Swapchains => Swapchains'Address,
               p_Image_Indices => Image_Indices'Address,
               p_Results => System.Null_Address);
         begin
            Result := Vk.Reset_Command_Buffer (Command_Buffer, 0);
            if Result /= Vk.SUCCESS then
               Status := Reset_Command_Buffer_Failed;
               return;
            end if;

            Result :=
              Vk.Begin_Command_Buffer (Command_Buffer, Begin_Info'Address);
            if Result /= Vk.SUCCESS then
               Status := Begin_Command_Buffer_Failed;
               return;
            end if;

            Vk.Cmd_Begin_Render_Pass
              (Command_Buffer, Render_Info'Address, Vk.SUBPASS_CONTENTS_INLINE);
            Vk.Cmd_Bind_Pipeline
              (Command_Buffer,
               Vk.PIPELINE_BIND_POINT_GRAPHICS,
               Device.Graphics_Pipeline);
            if Device.Descriptor_Set /= System.Null_Address then
               Vk.Cmd_Bind_Descriptor_Sets
                 (Command_Buffer,
                  Vk.PIPELINE_BIND_POINT_GRAPHICS,
                  Device.Pipeline_Layout,
                  0,
                  1,
                  Device.Descriptor_Set'Address,
                  0,
                  System.Null_Address);
            end if;
            Vk.Cmd_Set_Viewport (Command_Buffer, 0, 1, Viewport'Address);
            Vk.Cmd_Set_Scissor (Command_Buffer, 0, 1, Scissor'Address);
            Vk.Cmd_Bind_Vertex_Buffers
              (Command_Buffer, 0, 1, Buffers'Address, Offsets'Address);
            Vk.Cmd_Draw
              (Command_Buffer,
               Interfaces.Unsigned_32 (Device.Uploaded_Vertex_Count),
               1,
               0,
               0);
            Vk.Cmd_End_Render_Pass (Command_Buffer);

            Result := Vk.End_Command_Buffer (Command_Buffer);
            if Result /= Vk.SUCCESS then
               Status := End_Command_Buffer_Failed;
               return;
            end if;

            Result :=
              Vk.Reset_Fences
                (Device.Device, 1, Device.In_Flight (Frame)'Address);
            if Result /= Vk.SUCCESS then
               Status := Reset_Fence_Failed;
               return;
            end if;

            Result :=
              Vk.Queue_Submit
                (Device.Queue, 1, Submit_Info'Address, Device.In_Flight (Frame));
            if Result /= Vk.SUCCESS then
               Status := Queue_Submit_Failed;
               return;
            end if;

            Result := Vk.Queue_Present_KHR (Device.Queue, Present_Info'Address);
            if Is_Swapchain_Stale (Result) then
               Status := Swapchain_Out_Of_Date;
               return;
            elsif Result /= Vk.SUCCESS then
               Status := Queue_Present_Failed;
               return;
            end if;
         end;
      end;

      Device.Rendered_Frame_Count := Device.Rendered_Frame_Count + 1;
      if Frame = Device.Sync_Frame_Count then
         Device.Current_Frame := 1;
      else
         Device.Current_Frame := Frame + 1;
      end if;
      Status := Ok;
   end Render;

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
         Uploaded_Text_Run_Count => Device.Uploaded_Text_Run_Count,
         Uploaded_Shaped_Glyph_Count => Device.Uploaded_Shaped_Glyph_Count,
         Rendered_Frame_Count => Device.Rendered_Frame_Count,
         Color_Sample_Count => Sample_Count_Value (Device.Color_Sample_Count),
         Color_MSAA_Created => Device.Color_MSAA_View /= System.Null_Address,
         Atlas_Image_Created => Device.Atlas_Image /= System.Null_Address,
         Atlas_View_Created => Device.Atlas_View /= System.Null_Address,
         Atlas_Sampler_Created => Device.Atlas_Sampler /= System.Null_Address,
         Atlas_Width => Device.Atlas_Width,
         Atlas_Height => Device.Atlas_Height,
         Atlas_Bytes => Device.Atlas_Bytes,
         Atlas_Upload_Count => Device.Atlas_Upload_Count,
         Swapchain_Width    => Device.Swapchain_Width,
         Swapchain_Height   => Device.Swapchain_Height,
         Last_Status        => Device.Last_Status);
   end Diagnostics;
end Terminal.App.Vulkan_Device;
