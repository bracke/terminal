with System;

package body Terminal.App.Vulkan_Presenter is
   use type System.Address;

   package VC renames Terminal.App.Vulkan_Context;
   package VD renames Terminal.App.Vulkan_Device;
   package VS renames Terminal.App.Vulkan_Submit;

   use type VS.Vertex_Array_Access;
   use type VD.Create_Status;
   use type VD.Render_Status;

   function To_Present_Status
     (Status : VD.Render_Status)
      return Present_Status is
   begin
      case Status is
         when VD.Ok =>
            return Ok;
         when VD.Acquire_Image_Failed =>
            return Acquire_Image_Failed;
         when VD.Swapchain_Out_Of_Date =>
            return Swapchain_Out_Of_Date;
         when VD.Wait_Fence_Failed =>
            return Wait_Fence_Failed;
         when VD.Reset_Fence_Failed =>
            return Reset_Fence_Failed;
         when VD.Reset_Command_Buffer_Failed =>
            return Reset_Command_Buffer_Failed;
         when VD.Begin_Command_Buffer_Failed =>
            return Begin_Command_Buffer_Failed;
         when VD.End_Command_Buffer_Failed =>
            return End_Command_Buffer_Failed;
         when VD.Queue_Submit_Failed =>
            return Queue_Submit_Failed;
         when VD.Queue_Present_Failed =>
            return Queue_Present_Failed;
         when others =>
            return Render_Failed;
      end case;
   end To_Present_Status;

   function Has_Surface (Context : VC.Context) return Boolean is
     (VC.Surface (Context) /= System.Null_Address);

   function Batch_Is_Valid (Batch : VS.Submission_Batch) return Boolean is
   begin
      if VS.Width (Batch) = 0
        or else VS.Height (Batch) = 0
        or else VS.Vertex_Count (Batch) = 0
        or else VS.Vertices (Batch) = null
      then
         return False;
      end if;

      if VS.Text_Atlas_Used (Batch) then
         return VS.Atlas_Width (Batch) > 0
           and then VS.Atlas_Height (Batch) > 0
           and then VS.Atlas_Bytes (Batch) > 0
           and then VS.Atlas_Pixels (Batch) /= System.Null_Address;
      end if;

      return True;
   end Batch_Is_Valid;

   procedure Remember_Rejection
     (P      : in out Presenter;
      Status : Present_Status) is
   begin
      P.Rejected_Frames := P.Rejected_Frames + 1;
      P.Last_Status := Status;
      P.Last_Vertex_Count := 0;
      P.Last_Text_Run_Count := 0;
      P.Last_Frame_Width := 0;
      P.Last_Frame_Height := 0;
      P.Last_Atlas_Bytes := 0;
      P.Atlas_Dirty := False;
   end Remember_Rejection;

   procedure Initialize
     (P       : out Presenter;
      Context : VC.Context;
      Status  : out Init_Status;
      Desired_Width : Natural := 0;
      Desired_Height : Natural := 0) is
   begin
      P.Initialized := False;
      P.Context_Ready := False;
      P.Surface_Ready := False;
      P.Accepted_Frames := 0;
      P.Rejected_Frames := 0;
      P.Last_Status := Not_Initialized;
      P.Last_Vertex_Count := 0;
      P.Last_Text_Run_Count := 0;
      P.Last_Frame_Width := 0;
      P.Last_Frame_Height := 0;
      P.Last_Atlas_Bytes := 0;
      P.Atlas_Dirty := False;

      if not VC.Is_Initialized (Context) then
         Status := Context_Not_Initialized;
         return;
      end if;

      if not Has_Surface (Context) then
         Status := Surface_Unavailable;
         return;
      end if;

      declare
         Device_Status : VD.Select_Status;
         Create_Status : VD.Create_Status;
      begin
         VD.Select_Physical_Device (Context, P.Device, Device_Status);
         case Device_Status is
            when VD.Ok =>
               null;
            when VD.Surface_Query_Failed =>
               Status := Surface_Query_Failed;
               return;
            when others =>
               Status := No_Suitable_Device;
               return;
         end case;

         VD.Create_Logical_Device
           (Choice         => P.Device,
            Surface        => VC.Surface (Context),
            Desired_Width  => Desired_Width,
            Desired_Height => Desired_Height,
            Device         => P.Logical_Device,
            Status         => Create_Status);
         case Create_Status is
            when VD.Ok =>
               null;
            when VD.Swapchain_Extension_Missing =>
               Status := Swapchain_Extension_Missing;
               return;
            when VD.Queue_Unavailable =>
               Status := Queue_Unavailable;
               return;
            when VD.Invalid_Extent =>
               Status := Invalid_Extent;
               return;
            when VD.Create_Swapchain_Failed =>
               Status := Create_Swapchain_Failed;
               return;
            when VD.Get_Swapchain_Images_Failed =>
               Status := Get_Swapchain_Images_Failed;
               return;
            when VD.Too_Many_Swapchain_Images =>
               Status := Too_Many_Swapchain_Images;
               return;
            when VD.Create_Image_View_Failed =>
               Status := Create_Image_View_Failed;
               return;
            when VD.Create_Render_Pass_Failed =>
               Status := Create_Render_Pass_Failed;
               return;
            when VD.Create_Framebuffer_Failed =>
               Status := Create_Framebuffer_Failed;
               return;
            when VD.Create_Command_Pool_Failed =>
               Status := Create_Command_Pool_Failed;
               return;
            when VD.Allocate_Command_Buffers_Failed =>
               Status := Allocate_Command_Buffers_Failed;
               return;
            when VD.Create_Sync_Failed =>
               Status := Create_Sync_Failed;
               return;
            when VD.Create_Pipeline_Layout_Failed =>
               Status := Create_Pipeline_Layout_Failed;
               return;
            when VD.Create_Descriptor_Set_Layout_Failed =>
               Status := Create_Descriptor_Set_Layout_Failed;
               return;
            when VD.Create_Descriptor_Pool_Failed =>
               Status := Create_Descriptor_Pool_Failed;
               return;
            when VD.Allocate_Descriptor_Set_Failed =>
               Status := Allocate_Descriptor_Set_Failed;
               return;
            when VD.Create_Atlas_Sampler_Failed =>
               Status := Create_Atlas_Sampler_Failed;
               return;
            when VD.Shader_Load_Failed =>
               Status := Shader_Load_Failed;
               return;
            when VD.Create_Shader_Module_Failed =>
               Status := Create_Shader_Module_Failed;
               return;
            when VD.Create_Graphics_Pipeline_Failed =>
               Status := Create_Graphics_Pipeline_Failed;
               return;
            when VD.Vertex_Buffer_Too_Large =>
               Status := Vertex_Buffer_Too_Large;
               return;
            when VD.Create_Vertex_Buffer_Failed =>
               Status := Create_Vertex_Buffer_Failed;
               return;
            when VD.Allocate_Vertex_Memory_Failed =>
               Status := Allocate_Vertex_Memory_Failed;
               return;
            when VD.Bind_Vertex_Buffer_Failed =>
               Status := Bind_Vertex_Buffer_Failed;
               return;
            when VD.Map_Vertex_Buffer_Failed =>
               Status := Map_Vertex_Buffer_Failed;
               return;
            when VD.Atlas_Too_Large =>
               Status := Atlas_Too_Large;
               return;
            when VD.Create_Atlas_Image_Failed =>
               Status := Create_Atlas_Image_Failed;
               return;
            when VD.Allocate_Atlas_Memory_Failed =>
               Status := Allocate_Atlas_Memory_Failed;
               return;
            when VD.Bind_Atlas_Image_Failed =>
               Status := Bind_Atlas_Image_Failed;
               return;
            when VD.Create_Atlas_View_Failed =>
               Status := Create_Atlas_View_Failed;
               return;
            when VD.Create_Atlas_Staging_Buffer_Failed =>
               Status := Create_Atlas_Staging_Buffer_Failed;
               return;
            when VD.Allocate_Atlas_Staging_Memory_Failed =>
               Status := Allocate_Atlas_Staging_Memory_Failed;
               return;
            when VD.Bind_Atlas_Staging_Buffer_Failed =>
               Status := Bind_Atlas_Staging_Buffer_Failed;
               return;
            when VD.Map_Atlas_Staging_Buffer_Failed =>
               Status := Map_Atlas_Staging_Buffer_Failed;
               return;
            when VD.Copy_Atlas_Failed =>
               Status := Copy_Atlas_Failed;
               return;
            when others =>
               Status := Create_Device_Failed;
               return;
         end case;
      end;

      P.Initialized := True;
      P.Context_Ready := True;
      P.Surface_Ready := True;
      P.Last_Status := Validated_Not_Presented;
      Status := Ok;
   end Initialize;

   procedure Present
     (P       : in out Presenter;
      Context : VC.Context;
      Batch   : VS.Submission_Batch;
      Status  : out Present_Status) is
   begin
      if not P.Initialized then
         Status := Not_Initialized;
         Remember_Rejection (P, Status);
         return;
      end if;

      if not VC.Is_Initialized (Context) or else not Has_Surface (Context) then
         P.Context_Ready := VC.Is_Initialized (Context);
         P.Surface_Ready := Has_Surface (Context);
         Status := Invalid_Context;
         Remember_Rejection (P, Status);
         return;
      end if;

      if not VD.Is_Initialized (P.Logical_Device) then
         Status := Invalid_Context;
         Remember_Rejection (P, Status);
         return;
      end if;

      P.Context_Ready := True;
      P.Surface_Ready := True;

      if not Batch_Is_Valid (Batch) then
         Status := Invalid_Batch;
         Remember_Rejection (P, Status);
         return;
      end if;

      declare
         Upload_Status : VD.Create_Status;
         Render_Status : VD.Render_Status;
      begin
         VD.Upload (P.Logical_Device, P.Device, Batch, Upload_Status);
         if Upload_Status /= VD.Ok then
            case Upload_Status is
               when VD.Atlas_Too_Large
                  | VD.Create_Atlas_Image_Failed
                  | VD.Allocate_Atlas_Memory_Failed
                  | VD.Bind_Atlas_Image_Failed
                  | VD.Create_Atlas_View_Failed
                  | VD.Create_Atlas_Staging_Buffer_Failed
                  | VD.Allocate_Atlas_Staging_Memory_Failed
                  | VD.Bind_Atlas_Staging_Buffer_Failed
                  | VD.Map_Atlas_Staging_Buffer_Failed
                  | VD.Copy_Atlas_Failed =>
                  Status := Atlas_Upload_Failed;
               when others =>
                  Status := Upload_Failed;
            end case;
            Remember_Rejection (P, Status);
            return;
         end if;

         VD.Render (P.Logical_Device, Render_Status);
         if Render_Status /= VD.Ok then
            Status := To_Present_Status (Render_Status);
            Remember_Rejection (P, Status);
            return;
         end if;
      end;

      P.Accepted_Frames := P.Accepted_Frames + 1;
      P.Last_Vertex_Count := VS.Vertex_Count (Batch);
      P.Last_Text_Run_Count := VS.Text_Run_Count (Batch);
      P.Last_Frame_Width := VS.Width (Batch);
      P.Last_Frame_Height := VS.Height (Batch);
      P.Last_Atlas_Bytes := VS.Atlas_Bytes (Batch);
      P.Atlas_Dirty := VS.Atlas_Dirty (Batch);
      P.Last_Status := Ok;
      Status := Ok;
   end Present;

   procedure Finalize (P : in out Presenter) is
   begin
      VD.Finalize (P.Logical_Device);
      P.Initialized := False;
      P.Context_Ready := False;
      P.Surface_Ready := False;
      P.Last_Status := Not_Initialized;
   end Finalize;

   function Diagnostics (P : Presenter) return Diagnostic_Snapshot is
   begin
      return
        (Initialized       => P.Initialized,
         Context_Ready     => P.Context_Ready,
         Surface_Ready     => P.Surface_Ready,
         Accepted_Frames   => P.Accepted_Frames,
         Rejected_Frames   => P.Rejected_Frames,
         Last_Status       => P.Last_Status,
         Last_Vertex_Count => P.Last_Vertex_Count,
         Last_Text_Run_Count => P.Last_Text_Run_Count,
         Last_Frame_Width  => P.Last_Frame_Width,
         Last_Frame_Height => P.Last_Frame_Height,
         Last_Atlas_Bytes  => P.Last_Atlas_Bytes,
         Atlas_Dirty       => P.Atlas_Dirty,
         Device            => VD.Diagnostics (P.Device),
         Logical_Device    => VD.Diagnostics (P.Logical_Device));
   end Diagnostics;
end Terminal.App.Vulkan_Presenter;
