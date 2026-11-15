with Ada.Finalization;
with Interfaces;
with Interfaces.C;
with GLFW_Vulkan.Raw;
with GLFW_Vulkan.Runtime_State;
with GLFW_Vulkan.Surfaces;

package body GLFW_Vulkan is
   use type Interfaces.C.int;
   use type Interfaces.Unsigned_64;
   use type GLFW_Vulkan.Runtime_State.Runtime_Phase;

   Runtime_Leases : GLFW_Vulkan.Runtime_State.Manager;

   procedure Retain_Runtime (Lease : in out Runtime_Lease) is
   begin
      GLFW_Vulkan.Runtime_State.Retain (Runtime_Leases, Lease);
   end Retain_Runtime;

   procedure Release_Runtime (Lease : in out Runtime_Lease) is
      Cancel_Without_Raw_Runtime : constant Boolean :=
        Lease.Needs_Start and then not Lease.Raw_Started;
   begin
      if Lease.Needs_Start then
         GLFW_Vulkan.Runtime_State.Cancel_Start (Runtime_Leases, Lease);
      elsif Lease.Acquired then
         GLFW_Vulkan.Runtime_State.Release (Runtime_Leases, Lease);
      end if;
      if Lease.Needs_Stop then
         if Cancel_Without_Raw_Runtime then
            Lease.Raw_Stopped := 1;
         elsif Lease.Raw_Stopped = 0 then
            Raw.Terminate_Tracked (Lease.Raw_Stopped'Access);
         end if;
         Lease.Raw_Started := False;
         GLFW_Vulkan.Runtime_State.Complete_Stop
           (Runtime_Leases, Lease, True);
      end if;
   exception
      when others =>
         if Lease.Needs_Stop then
            begin
               GLFW_Vulkan.Runtime_State.Complete_Stop
                 (Runtime_Leases, Lease, Lease.Raw_Stopped /= 0);
            exception
               when others =>
                  GLFW_Vulkan.Runtime_State.Quarantine (Runtime_Leases);
                  Lease.Needs_Stop := False;
                  Lease.Generation := 0;
            end;
         end if;
         raise;
   end Release_Runtime;

   procedure Initialize
     (Ctx    : in out Context;
      Status : out Init_Status)
   is
   begin
      if Ctx.Initialized then
         Status := Already_Initialized;
         return;
      end if;

      GLFW_Vulkan.Runtime_State.Acquire
        (Runtime_Leases, Ctx.Lease);
      if not Ctx.Lease.Acquired then
         Status := Runtime_Unavailable;
         return;
      end if;
      if Ctx.Lease.Needs_Start then
         Ctx.Lease.Raw_Started := True;
         if Raw.Init = 0 then
            Ctx.Lease.Raw_Started := False;
            GLFW_Vulkan.Runtime_State.Complete_Start
              (Runtime_Leases, Ctx.Lease, False);
            Status := GLFW_Init_Failed;
            return;
         end if;
         if not Surfaces.Vulkan_Supported then
            Raw.Terminate_Tracked (Ctx.Lease.Raw_Stopped'Access);
            Ctx.Lease.Raw_Started := False;
            GLFW_Vulkan.Runtime_State.Complete_Start
              (Runtime_Leases, Ctx.Lease, False);
            Status := Vulkan_Not_Supported;
            return;
         end if;
         GLFW_Vulkan.Runtime_State.Complete_Start
           (Runtime_Leases, Ctx.Lease, True);
         Ctx.Lease.Raw_Started := False;
      end if;

      Ctx.Initialized := True;
      Status := Ok;
   exception
      when others =>
         Ctx.Initialized := False;
         Release_Runtime (Ctx.Lease);
         raise;
   end Initialize;

   overriding procedure Finalize (Ctx : in out Context) is
   begin
      if Ctx.Initialized then
         Ctx.Initialized := False;
      end if;
      Release_Runtime (Ctx.Lease);
   exception
      --  Controlled finalization must not replace an exception already
      --  unwinding the enclosing scope. Quarantine any transition that the
      --  normal release recovery could not finish, and clear the dying lease.
      when others =>
         begin
            if GLFW_Vulkan.Runtime_State.Phase (Runtime_Leases) /=
              GLFW_Vulkan.Runtime_State.Failed
            then
               GLFW_Vulkan.Runtime_State.Quarantine (Runtime_Leases);
            end if;
         exception
            when others => null;
         end;
         Ctx.Lease.Acquired := False;
         Ctx.Lease.Needs_Start := False;
         Ctx.Lease.Needs_Stop := False;
         Ctx.Lease.Raw_Started := False;
         Ctx.Lease.Raw_Stopped := 0;
         Ctx.Lease.Generation := 0;
   end Finalize;

   function Is_Initialized (Ctx : Context) return Boolean is
     (Ctx.Initialized);

   function Runtime_Transition_Failure_Count return Natural is
     (GLFW_Vulkan.Runtime_State.Transition_Failure_Count (Runtime_Leases));
end GLFW_Vulkan;
