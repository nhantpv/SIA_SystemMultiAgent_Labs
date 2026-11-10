// Runs NetLogo commands headless, as if typed in the Command Center.
// Usage: java -cp "<NetLogo>/app/netlogo-7.0.4.jar;tools" NLRun <model.nlogo> < commands.txt
// Each line of stdin is one observer command. A line starting with "? " is a reporter:
// its value is printed. "print" / "show" output goes to stdout, as in the Command Center.
import org.nlogo.headless.HeadlessWorkspace;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class NLRun {
    public static void main(String[] args) throws Exception {
        HeadlessWorkspace ws = HeadlessWorkspace.newInstance();
        try {
            ws.open(args[0], false);
            BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
            String line;
            while ((line = in.readLine()) != null) {
                line = line.strip();
                if (line.isEmpty() || line.startsWith(";")) continue;
                try {
                    if (line.startsWith("? ")) {
                        System.out.println(org.nlogo.api.Dump.logoObject(ws.report(line.substring(2)), true, false));
                    } else {
                        ws.command(line);
                    }
                } catch (Exception ex) {
                    System.out.println("ERROR: " + ex.getMessage() + "  <- " + line);
                }
                System.out.flush();
            }
        } finally {
            ws.dispose();
        }
    }
}
