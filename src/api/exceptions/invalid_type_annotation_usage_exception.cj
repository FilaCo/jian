protected package jian.api.exceptions

public class InvalidTypeAnnotationUsageException <: Exception {
    protected InvalidTypeAnnotationUsageException(typeAnnotationName: String) {
        super("${typeAnnotationName} can appear only on arguments of ca @Callback or @Command macro.")
    }

    protected func getClassName(): String {
        "InvalidTypeAnnotationUsageException"
    }
}
