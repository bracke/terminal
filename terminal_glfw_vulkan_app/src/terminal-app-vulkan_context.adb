with Ada.Characters.Handling;
with Interfaces.C.Strings;
with Interfaces.C;
with GLFW_Vulkan.Surfaces;
with System;

package body Terminal.App.Vulkan_Context is
   use type GLFW_Vulkan.Surfaces.Surface_Status;
   use type Interfaces.C.Strings.chars_ptr;
   use type Vk.Result_T;
   use type Vk.Instance_T;
   use type Vk.Surface_KHR_T;

   function Humanize (Text : String) return String is
      Result : String (1 .. Text'Length);
      At_Word_Start : Boolean := True;
   begin
      for I in Text'Range loop
         declare
            Ch : constant Character := Text (I);
            Out_Index : constant Positive := I - Text'First + 1;
         begin
            if Ch = '_' then
               Result (Out_Index) := ' ';
               At_Word_Start := True;
            elsif At_Word_Start then
               Result (Out_Index) := Ada.Characters.Handling.To_Upper (Ch);
               At_Word_Start := False;
            else
               Result (Out_Index) := Ada.Characters.Handling.To_Lower (Ch);
            end if;
         end;
      end loop;
      return Result;
   end Humanize;

   function Status_Label (Status : Init_Status) return String is
      Label : constant String :=
        "Vulkan context: " & Humanize (Init_Status'Image (Status));
   begin
      if Label'Length > Max_Status_Label_Length then
         return Label (1 .. Max_Status_Label_Length);
      else
         return Label;
      end if;
   end Status_Label;

   type Chars_Ptr_Array is
     array (Positive range <>) of Interfaces.C.Strings.chars_ptr
     with Convention => C;

   procedure Free_All (Items : in out Chars_Ptr_Array) is
   begin
      for Item of Items loop
         if Item /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Item);
         end if;
      end loop;
   end Free_All;

   procedure Initialize
     (Ctx    : out Context;
      Window : GLFW_Vulkan.Windows.Window;
      Status : out Init_Status)
   is
      Extensions : constant GLFW_Vulkan.Surfaces.Extension_Name_Array :=
        GLFW_Vulkan.Surfaces.Required_Instance_Extensions;
      App_Name : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C ("Ada Terminal");
      Engine_Name : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C ("terminal_glfw_vulkan_app");
      Inst : aliased Vk.Instance_T := System.Null_Address;
   begin
      Ctx.Initialized := False;
      Ctx.Instance := System.Null_Address;
      Ctx.Surface := System.Null_Address;

      if Extensions'Length = 0 then
         Status := GLFW_Extensions_Unavailable;
         return;
      end if;

      declare
         C_Extensions : Chars_Ptr_Array (1 .. Extensions'Length);
      begin
         for I in C_Extensions'Range loop
            C_Extensions (I) :=
              Interfaces.C.Strings.New_String
                (GLFW_Vulkan.Surfaces.To_String (Extensions (I)));
         end loop;

         declare
            App_Info : aliased Vk.Application_Info_T :=
              (s_Type              => Vk.STRUCTURE_TYPE_APPLICATION_INFO,
               p_Next              => System.Null_Address,
               p_Application_Name  => App_Name'Address,
               application_Version => 1,
               p_Engine_Name       => Engine_Name'Address,
               engine_Version      => 1,
               api_Version         => 0);
            Create_Info : aliased Vk.Instance_Create_Info_T :=
              (s_Type                     => Vk.STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
               p_Next                     => System.Null_Address,
               flags                      => 0,
               p_Application_Info         => App_Info'Address,
               enabled_Layer_Count        => 0,
               pp_Enabled_Layer_Names     => System.Null_Address,
               enabled_Extension_Count    => Interfaces.Unsigned_32 (C_Extensions'Length),
               pp_Enabled_Extension_Names => C_Extensions'Address);
            Result : constant Vk.Result_T :=
              Vk.Create_Instance
                (Create_Info'Address,
                 System.Null_Address,
                 Inst'Address);
         begin
            if Result /= Vk.SUCCESS then
               Free_All (C_Extensions);
               Status := Instance_Create_Failed;
               return;
            end if;
         end;

         Free_All (C_Extensions);
      end;

      Ctx.Instance := Inst;

      declare
         Surface_Status : GLFW_Vulkan.Surfaces.Surface_Status;
      begin
         GLFW_Vulkan.Surfaces.Create_Surface
           (Window   => Window,
            Instance => Ctx.Instance,
            Surface  => Ctx.Surface,
            Status   => Surface_Status);
         if Surface_Status /= GLFW_Vulkan.Surfaces.Ok then
            Vk.Destroy_Instance (Ctx.Instance, System.Null_Address);
            Ctx.Instance := System.Null_Address;
            Status := Surface_Create_Failed;
            return;
         end if;
      end;

      Ctx.Initialized := True;
      Status := Ok;
   end Initialize;

   procedure Finalize (Ctx : in out Context) is
   begin
      if Ctx.Surface /= System.Null_Address and then Ctx.Instance /= System.Null_Address then
         Vk.Destroy_Surface_KHR (Ctx.Instance, Ctx.Surface, System.Null_Address);
         Ctx.Surface := System.Null_Address;
      end if;
      if Ctx.Instance /= System.Null_Address then
         Vk.Destroy_Instance (Ctx.Instance, System.Null_Address);
         Ctx.Instance := System.Null_Address;
      end if;
      Ctx.Initialized := False;
   end Finalize;

   function Is_Initialized (Ctx : Context) return Boolean is
     (Ctx.Initialized);

   function Instance (Ctx : Context) return Vk.Instance_T is
     (Ctx.Instance);

   function Surface (Ctx : Context) return Vk.Surface_KHR_T is
     (Ctx.Surface);
end Terminal.App.Vulkan_Context;
