with Interfaces.C.Strings;
with Interfaces.C;
with GLFW_Vulkan.Surfaces;
with System;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Status_Labels;
with Terminal.App.Vulkan_Destroy_Pair;
with Terminal.Common.C_Strings;

package body Terminal.App.Vulkan_Context is
   use type GLFW_Vulkan.Surfaces.Surface_Status;
   use type Vk.Result_T;
   use type Vk.Instance_T;
   use type Vk.Surface_KHR_T;

   function Humanize (Text : String) return String
      renames Terminal.App.Status_Labels.Humanize;

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

   type C_String_Owner_Array is
     array (Positive range <>) of Terminal.Common.C_Strings.Owner;

   procedure Initialize
     (Ctx    : in out Context;
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
      --  An out formal does not finalize an existing limited controlled
      --  actual.  Release any previous instance and surface explicitly before
      --  beginning a new ownership transaction.
      Finalize (Ctx);

      if Extensions'Length = 0 then
         Status := GLFW_Extensions_Unavailable;
         return;
      end if;

      declare
         Extension_Owners : C_String_Owner_Array (1 .. Extensions'Length);
         C_Extensions : Chars_Ptr_Array (1 .. Extensions'Length) :=
           (others => Interfaces.C.Strings.Null_Ptr);
      begin
         for I in C_Extensions'Range loop
            Terminal.Common.C_Strings.Set
              (Extension_Owners (I),
               GLFW_Vulkan.Surfaces.To_String (Extensions (I)));
            C_Extensions (I) :=
              Terminal.Common.C_Strings.Unsafe_Pointer
                (Extension_Owners (I));
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
               Status := Instance_Create_Failed;
               return;
            end if;
            --  Publish ownership immediately.  Any subsequent exception is
            --  then handled by the context's normal idempotent finalizer.
            Ctx.Instance := Inst;
         end;
      end;

      declare
         Surface_Status : GLFW_Vulkan.Surfaces.Surface_Status;
      begin
         GLFW_Vulkan.Surfaces.Create_Surface
           (Window   => Window,
            Instance => Ctx.Instance,
            Surface  => Ctx.Surface,
            Status   => Surface_Status);
         if Surface_Status /= GLFW_Vulkan.Surfaces.Ok then
            Finalize (Ctx);
            Status := Surface_Create_Failed;
            return;
         end if;
      end;

      Ctx.Initialized := True;
      Status := Ok;
   exception
      when others =>
         Finalize (Ctx);
         raise;
   end Initialize;

   overriding procedure Finalize (Ctx : in out Context) is
      Cleanup_Succeeded : Boolean := True;

      procedure Destroy_Surface_Call (Handle : Vk.Surface_KHR_T) is
         Owned : Vk.Surface_KHR_T := Handle;
      begin
         GLFW_Vulkan.Surfaces.Destroy_Surface (Ctx.Instance, Owned);
      end Destroy_Surface_Call;

      procedure Destroy_Instance_Call (Handle : Vk.Instance_T) is
      begin
         Vk.Destroy_Instance (Handle, System.Null_Address);
      end Destroy_Instance_Call;

      procedure Destroy_Context_Chain is new Terminal.App.Vulkan_Destroy_Pair
        (Vk.Surface_KHR_T, System.Null_Address,
         "destroy Vulkan surface", Destroy_Surface_Call,
         Vk.Instance_T, System.Null_Address,
         "destroy Vulkan instance", Destroy_Instance_Call,
         Terminal.App.Cleanup_Diagnostics.Vulkan_Context);
   begin
      if Ctx.Surface /= System.Null_Address
        and then Ctx.Instance = System.Null_Address
      then
         --  A surface without its parent instance cannot be passed safely to
         --  Vulkan.  Forget the corrupted ownership marker and report the
         --  quarantine rather than dereferencing a null parent.
         Ctx.Surface := System.Null_Address;
         Cleanup_Succeeded := False;
      else
         Destroy_Context_Chain
           (Ctx.Surface, Ctx.Instance, Cleanup_Succeeded);
      end if;
      if not Cleanup_Succeeded then
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Vulkan_Context,
            "quarantine Vulkan instance after incomplete child cleanup");
      end if;
      Ctx.Initialized := False;
   exception
      when E : others =>
         Ctx.Initialized := False;
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Vulkan_Context,
            E,
            "finalize Vulkan context");
   end Finalize;

   function Is_Initialized (Ctx : Context) return Boolean is
     (Ctx.Initialized);

   function Instance (Ctx : Context) return Vk.Instance_T is
     (Ctx.Instance);

   function Surface (Ctx : Context) return Vk.Surface_KHR_T is
     (Ctx.Surface);
end Terminal.App.Vulkan_Context;
