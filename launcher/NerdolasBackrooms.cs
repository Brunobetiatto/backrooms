// NerdolasBackrooms.exe: roda o atualizar.ps1 (embutido no exe), que baixa a versao mais nova
// da main, compila o jogo e abre. Tudo fica na pasta deste exe (jogo\ e .ferramentas\). Para gerar o exe de novo: launcher\compilar_launcher.bat
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

class NerdolasBackrooms {
    static int Main(string[] args) {
        // o jogo e as ferramentas ficam na pasta deste exe (sem a barra final, que escaparia a aspa)
        string baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
        string script = Path.Combine(Path.GetTempPath(), "backrooms_atualizar.ps1");
        using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("atualizar.ps1"))
        using (FileStream f = File.Create(script)) s.CopyTo(f);

        ProcessStartInfo psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" -Base \"" + baseDir + "\" " + string.Join(" ", args));
        psi.UseShellExecute = false;
        Process p = Process.Start(psi);
        p.WaitForExit();
        return p.ExitCode;
    }
}
