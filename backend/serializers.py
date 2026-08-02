from rest_framework import serializers  # type: ignore[import]
from django.core.validators import RegexValidator  # type: ignore[import]


class StudentOnboardingSerializer(serializers.Serializer):
    # Field definitions with absolute validation limits
    student_id = serializers.CharField(
        max_length=12,
        min_length=6,
        validators=[
            RegexValidator(
                r"^STU-[0-9]{7}$", message="Student ID must match format STU-XXXXXXX"
            )
        ],
    )
    parent_email = serializers.EmailField(max_length=254)

    # Binary DCYN Logic Library Mapping
    requires_lsa_support = serializers.BooleanField(required=True)
    has_medical_diagnosis = serializers.BooleanField(required=True)
    consent_data_sharing = serializers.BooleanField(required=True)

    def validate_consent_data_sharing(self, value):
        """DCYN_03 Enforcement: Reject pipeline entry without explicit consent."""
        if not value:
            raise serializers.ValidationError(
                "Compliance Violation: Onboarding payload cannot be processed into GCP pipelines without data sharing consent."
            )
        return value

    def validate(self, attrs):
        """Zero-judgment cross-field deterministic mapping logic."""
        # Convert incoming payload to normalized DCYN Binary Map
        attrs["dcyn_matrix"] = {
            "DCYN_01_LSA_REQUIRED": 1 if attrs.get("requires_lsa_support") else 0,
            "DCYN_02_DIAGNOSIS_PRESENT": 1 if attrs.get("has_medical_diagnosis") else 0,
            "DCYN_03_CONSENT_GRANTED": 1 if attrs.get("consent_data_sharing") else 0,
        }
        return attrs
